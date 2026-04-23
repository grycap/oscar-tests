(function () {
  const data = window.OSCAR_SCALABILITY_DATA || { experiments: [] };
  const experiments = data.experiments || [];
  const colors = {
    sync: "#0f766e",
    async: "#b42318",
    preRun: "#2563eb",
    run: "#b7791f",
    completion: "#6b7280",
    green: "#0f766e",
    red: "#b42318",
    blue: "#2563eb",
    yellow: "#b7791f",
  };
  const tooltip = d3.select("body").append("div").attr("class", "tooltip");

  function fmt(value, digits = 2, suffix = "") {
    if (value === null || value === undefined || Number.isNaN(value)) return "-";
    if (typeof value === "number") return `${value.toFixed(digits)}${suffix}`;
    return `${value}${suffix}`;
  }

  function stepRows(experiment) {
    return (experiment.steps || []).map((step) => ({
      experiment: experiment.experiment_id,
      mode: step.mode,
      users: step.users,
      requests: step.locust?.requests || 0,
      failures: step.locust?.failures || 0,
      failureRate: step.locust?.failure_rate || 0,
      rps: step.locust?.requests_per_second,
      p95: step.locust?.latency_ms?.p95,
      completionP95: step.jobs?.completion_seconds?.p95,
      preRunP95: step.jobs?.pre_run_seconds?.p95,
      runP95: step.jobs?.run_seconds?.p95,
      unfinished: step.jobs?.unfinished,
      statuses: step.jobs?.status_counts || {},
    }));
  }

  function selectedExperiment() {
    const id = d3.select("#experimentSelect").property("value");
    return experiments.find((item) => item.experiment_id === id) || experiments[0];
  }

  function init() {
    const select = d3.select("#experimentSelect");
    select
      .selectAll("option")
      .data(experiments)
      .join("option")
      .attr("value", (d) => d.experiment_id)
      .text((d) => `${d.experiment_id} (${d.created_at})`);
    select.on("change", render);
    setupHeaderTooltips();
    render();
  }

  function render() {
    const experiment = selectedExperiment();
    if (!experiment) {
      d3.select("main").html("<section><h2>No experiments found</h2><p>Run the scalability suite first.</p></section>");
      return;
    }
    const rows = stepRows(experiment);
    renderSummary(experiment, rows);
    renderBaseline(experiment);
    renderInvocationBaseline(experiment);
    renderFindings(experiment, rows);
    renderTable(rows);
    lineChart("#throughputChart", rows.filter((d) => d.rps !== null && d.rps !== undefined), "rps", "Requests/s", {
      valueFormatter: (value) => fmt(value, 2, " req/s"),
    });
    lineChart("#latencyChart", rows.filter((d) => d.p95 !== null && d.p95 !== undefined), "p95", "P95 HTTP latency (ms)", {
      labelFor: latencySeriesLabel,
      valueFormatter: (value) => fmt(value, 0, " ms"),
    });
    lineChart("#completionChart", rows.filter((d) => d.mode === "async" && d.completionP95 !== null && d.completionP95 !== undefined), "completionP95", "P95 seconds", {
      labelFor: () => "async end-to-end",
      colorFor: () => colors.completion,
      valueFormatter: (value) => fmt(value, 2, " s"),
      metricLabel: "P95 end-to-end",
    });
    barChart("#failureChart", rows, "failureRate", "Failure rate", (v) => `${(v * 100).toFixed(1)}%`);
    lifecycleChart("#lifecycleChart", rows.filter((d) => d.mode === "async"));
    statusChart("#statusChart", rows.filter((d) => d.mode === "async"));
    renderReproducibility(experiment);
  }

  function renderSummary(experiment, rows) {
    const quota = experiment.platform?.quota || {};
    const totals = {
      requests: d3.sum(rows, (d) => d.requests),
      failures: d3.sum(rows, (d) => d.failures),
      maxP95: d3.max(rows, (d) => d.p95),
      maxCompletion: d3.max(rows, (d) => d.completionP95),
      safe: quota.safe_parallel_capacity,
    };
    const cards = [
      ["Experiment", experiment.experiment_id],
      ["Total requests", totals.requests],
      ["HTTP failures", totals.failures],
      ["Max HTTP P95", fmt(totals.maxP95, 0, " ms")],
      ["Max async E2E P95", fmt(totals.maxCompletion, 2, " s")],
      ["Quota safe capacity", fmt(totals.safe, 0)],
    ];
    d3.select("#summary")
      .selectAll(".metric")
      .data(cards)
      .join("div")
      .attr("class", "metric")
      .html((d) => `<span>${escapeHtml(d[0])}</span><strong>${escapeHtml(d[1])}</strong>`);
  }

  function renderReproducibility(experiment) {
    const config = experiment.run_configuration || {};
    const hasConfig = Boolean(Object.keys(config).length);
    d3.select("#reproducibilitySection").style("display", hasConfig ? null : "none");
    if (!hasConfig) return;

    const command = config.commands?.make || config.commands?.robot || "";
    d3.select("#reproducibilityCommand").text(command || "Command metadata was not available for this experiment.");

    d3.select("#reproducibilityNotes")
      .selectAll("li")
      .data(config.notes || [])
      .join("li")
      .text((d) => d);
  }

  function renderFindings(experiment, rows) {
    const findings = [];
    const safe = experiment.platform?.quota?.safe_parallel_capacity;
    if (safe !== null && safe !== undefined) findings.push(`Quota-derived safe parallel capacity is ${safe} invocations.`);
    ["sync", "async"].forEach((mode) => {
      const failed = rows.filter((d) => d.mode === mode && d.failures > 0).sort((a, b) => a.users - b.users)[0];
      findings.push(
        failed
          ? `${mode} first shows HTTP failures at ${failed.users} users (${(failed.failureRate * 100).toFixed(1)}%).`
          : `${mode} has no HTTP failures in the executed steps.`
      );
    });
    const unfinished = rows.filter((d) => d.mode === "async" && (d.unfinished || 0) > 0).sort((a, b) => a.users - b.users)[0];
    if (unfinished) findings.push(`Async has unfinished jobs from ${unfinished.users} users with the configured settle time.`);
    d3.select("#findings").selectAll("li").data(findings).join("li").text((d) => d);
  }

  function renderBaseline(experiment) {
    const quota = experiment.platform?.quota || {};
    const clusterStatus = experiment.cluster_status || experiment.platform?.cluster_status || {};
    const clusterResources = clusterResourcesFromStatus(experiment);
    const clusterCpu = clusterResources.cpu || {};
    const clusterMemory = clusterResources.memory || {};
    const service = experiment.service || {};
    const invocationResources = service.invocation_resources || fallbackInvocationResources(experiment);
    const serviceCards = [
      ["Service", service.name || "-"],
      ["OSCAR Hub", service.hub?.url ? { text: service.hub?.name || service.base || "service", href: service.hub.url } : "-"],
      ...Object.entries(invocationResources).map(([mode, resources]) => [
        `${mode} invocation resources`,
        `${fmt(resources.cpu_cores, 2, " CPU")} / ${fmt(resources.memory_mib, 0, " MiB")}`,
        "CPU and memory requested by the deployed OSCAR service for each invocation in this mode.",
      ]),
    ];
    d3.select("#clusterEndpoint").html(
      `<span>Cluster endpoint</span><strong>${escapeHtml(experiment.platform?.endpoint || "-")}</strong>`
    );
    const clusterCards = [
      ["Cluster total free CPU", fmt(clusterCpu.total_free_cores, 2, " cores")],
      ["Cluster max node CPU", fmt(clusterCpu.max_free_on_node_cores, 2, " cores")],
      ["Cluster total free memory", fmt(clusterMemory.total_free_mib, 0, " MiB")],
      ["Cluster max node memory", fmt(clusterMemory.max_free_on_node_mib, 0, " MiB")],
      ["Nodes", fmt(clusterResources.nodes_count, 0)],
      ["Captured at", clusterStatus.captured_at || "-"],
    ];
    const quotaCards = [
      ["Quota source", experiment.platform?.quota_source || "unavailable"],
      ["User quota free CPU", fmt(quota.cpu_available_cores, 2, " cores")],
      ["User quota free memory", fmt(quota.memory_available_mib, 0, " MiB")],
      [
        "Safe capacity",
        fmt(quota.safe_parallel_capacity, 0),
        "Estimated maximum parallel simple-test invocations that fit within the user's available CPU and memory quota.",
      ],
    ];

    renderCards("#serviceCards", serviceCards);
    renderCards("#clusterResourceCards", clusterCards);
    renderCards("#quotaCards", quotaCards);
  }

  function renderInvocationBaseline(experiment) {
    const baseline = experiment.baseline || {};
    const hasBaseline = Boolean(Object.keys(baseline).length);
    d3.select("#invocationBaselineSection").style("display", hasBaseline ? null : "none");
    if (!hasBaseline) return;

    const syncFirst = baseline.sync?.first_ready || {};
    const syncWarm = baseline.sync?.warm || {};
    const asyncFirst = baseline.async?.first_ready || {};
    const asyncWarm = baseline.async?.warm || {};
    const asyncWarmup = experiment.async_warmup?.summary || {};
    const cards = [
      [
        "Sync first ready",
        invocationValue(syncFirst.latency_ms, " ms", syncFirst.ok),
        "First synchronous /run invocation measured after the service was reported as ready.",
      ],
      [
        "Sync warm",
        invocationValue(syncWarm.latency_ms, " ms", syncWarm.ok),
        "Second synchronous /run invocation measured immediately after the first ready invocation.",
      ],
      [
        "Sync first/warm ratio",
        ratioValue(syncFirst.latency_ms, syncWarm.latency_ms),
        "Ratio between first ready sync latency and warm sync latency. Values above 1 indicate the first call was slower.",
      ],
      [
        "Async first submit",
        invocationValue(asyncFirst.submit?.latency_ms, " ms", asyncFirst.submit?.ok),
        "HTTP latency for the first isolated asynchronous /job submission.",
      ],
      [
        "Async first end-to-end",
        invocationValue(asyncFirst.job?.completion_seconds, " s", asyncFirst.job?.ok),
        "Completion time for the first isolated asynchronous job, from creation to terminal state.",
      ],
      [
        "Async warm submit",
        invocationValue(asyncWarm.submit?.latency_ms, " ms", asyncWarm.submit?.ok),
        "HTTP latency for the second isolated asynchronous /job submission.",
      ],
      [
        "Async warm end-to-end",
        invocationValue(asyncWarm.job?.completion_seconds, " s", asyncWarm.job?.ok),
        "Completion time for the second isolated asynchronous job, from creation to terminal state.",
      ],
      [
        "Async first/warm ratio",
        ratioValue(asyncFirst.job?.completion_seconds, asyncWarm.job?.completion_seconds),
        "Ratio between first ready async end-to-end time and warm async end-to-end time.",
      ],
    ];
    if (Object.keys(asyncWarmup).length) {
      cards.push(
        [
          "Async warm-up jobs",
          `${fmt(asyncWarmup.succeeded, 0)} / ${fmt(asyncWarmup.jobs, 0)} succeeded`,
          "Asynchronous jobs submitted and completed before the measured async Locust steps.",
        ],
        [
          "Async warm-up elapsed",
          fmt(asyncWarmup.elapsed_seconds, 2, " s"),
          "Wall-clock time spent warming the asynchronous path before measured async load.",
        ]
      );
    }

    renderCards("#invocationBaselineCards", cards);
    d3.select("#invocationBaselineCaveats")
      .selectAll("li")
      .data(baseline.caveats || [])
      .join("li")
      .text((d) => d);
  }

  function invocationValue(value, suffix, ok) {
    const digits = suffix.trim() === "ms" ? 0 : 2;
    const formatted = fmt(value, digits, suffix);
    if (formatted === "-") return ok === false ? "failed" : "-";
    return ok === false ? `${formatted} (failed)` : formatted;
  }

  function ratioValue(first, warm) {
    if (!Number.isFinite(Number(first)) || !Number.isFinite(Number(warm)) || Number(warm) === 0) return "-";
    return `${(Number(first) / Number(warm)).toFixed(2)}x`;
  }

  function renderCards(selector, cards) {
    d3.select(selector)
      .selectAll(".baseline-item")
      .data(cards)
      .join("div")
      .attr("class", "baseline-item")
      .attr("data-help", (d) => d[2] || null)
      .html((d) => `<span>${escapeHtml(d[0])}</span><strong>${formatCardValue(d[1])}</strong>`)
      .on("mousemove", (event, d) => {
        if (d[2]) showTip(event, d[2]);
      })
      .on("mouseleave", hideTip);
  }

  function formatCardValue(value) {
    if (value && typeof value === "object" && value.href) {
      return `<a href="${escapeHtml(value.href)}" target="_blank" rel="noopener noreferrer">${escapeHtml(value.text || value.href)}</a>`;
    }
    return escapeHtml(value);
  }

  function fallbackInvocationResources(experiment) {
    const modes = Array.from(new Set((experiment.steps || []).map((step) => step.mode))).sort();
    const service = experiment.service || {};
    const cpu = service.resources?.cpu_cores ?? service.cpu;
    const memory = service.resources?.memory_mib ?? service.memory_mib;
    return Object.fromEntries(modes.map((mode) => [mode, { cpu_cores: cpu, memory_mib: memory }]));
  }

  function clusterResourcesFromStatus(experiment) {
    const status = experiment.cluster_status || experiment.platform?.cluster_status || {};
    const direct = experiment.platform?.cluster_resources || status.resources || {};
    if (Object.keys(direct).length) return direct;
    return normalizeClusterResources(status.payload);
  }

  function normalizeClusterResources(payload) {
    const cluster = payload?.cluster || {};
    const metrics = cluster.metrics || {};
    const cpu = metrics.cpu || {};
    const memory = metrics.memory || {};
    const nodes = Array.isArray(cluster.nodes) ? cluster.nodes : [];
    const nodeCpuCapacity = nodes.map((node) => cpuToCores(node?.cpu?.capacity_cores)).filter((value) => value !== null);
    const nodeCpuUsage = nodes.map((node) => cpuToCores(node?.cpu?.usage_cores)).filter((value) => value !== null);
    const nodeMemoryCapacity = nodes.map((node) => bytesToMib(node?.memory?.capacity_bytes)).filter((value) => value !== null);
    const nodeMemoryUsage = nodes.map((node) => bytesToMib(node?.memory?.usage_bytes)).filter((value) => value !== null);
    return {
      nodes_count: cluster.nodes_count ?? nodes.length,
      cpu: {
        total_free_cores: cpuToCores(cpu.total_free_cores),
        max_free_on_node_cores: cpuToCores(cpu.max_free_on_node_cores),
        total_capacity_cores: sumOrNull(nodeCpuCapacity),
        total_used_cores: sumOrNull(nodeCpuUsage),
      },
      memory: {
        total_free_mib: bytesToMib(memory.total_free_bytes),
        max_free_on_node_mib: bytesToMib(memory.max_free_on_node_bytes),
        total_capacity_mib: sumOrNull(nodeMemoryCapacity),
        total_used_mib: sumOrNull(nodeMemoryUsage),
      },
      gpu: {
        total: metrics.gpu?.total_gpu,
      },
    };
  }

  function cpuToCores(value) {
    const amount = Number(value);
    if (!Number.isFinite(amount)) return null;
    return amount > 128 ? amount / 1000 : amount;
  }

  function bytesToMib(value) {
    const amount = Number(value);
    if (!Number.isFinite(amount)) return null;
    return amount / (1024 * 1024);
  }

  function sumOrNull(values) {
    return values.length ? d3.sum(values) : null;
  }

  function renderTable(rows) {
    d3.select("#stepsTable tbody")
      .selectAll("tr")
      .data(rows.slice().sort((a, b) => d3.ascending(a.mode, b.mode) || d3.ascending(a.users, b.users)))
      .join("tr")
      .html(
        (d) => `
        <td>${d.mode}</td>
        <td>${d.users}</td>
        <td>${d.requests}</td>
        <td>${d.failures}</td>
        <td>${(d.failureRate * 100).toFixed(1)}%</td>
        <td>${fmt(d.rps, 2)}</td>
        <td>${fmt(d.p95, 0, " ms")}</td>
        <td>${fmt(d.completionP95, 2, " s")}</td>
        <td>${fmt(d.preRunP95, 2, " s")}</td>
        <td>${fmt(d.unfinished, 0)}</td>`
      );
  }

  function chartFrame(selector) {
    const root = d3.select(selector);
    root.selectAll("*").remove();
    const width = root.node().clientWidth || 520;
    const height = 300;
    const margin = { top: 22, right: 26, bottom: 48, left: 60 };
    const svg = root.append("svg").attr("viewBox", `0 0 ${width} ${height}`);
    const legendNode = root.append("div").attr("class", "chart-legend");
    return { svg, legendNode, width, height, margin, innerW: width - margin.left - margin.right, innerH: height - margin.top - margin.bottom };
  }

  function lineChart(selector, rows, metric, yLabel, options = {}) {
    const c = chartFrame(selector);
    if (!rows.length) return emptyChart(c.svg, c.width, c.height);
    const valueFormatter = options.valueFormatter || ((value) => fmt(value, 2));
    const labelFor = options.labelFor || ((name) => name);
    const colorFor = options.colorFor || ((name) => colors[name] || colors.blue);
    const xDomain = d3.extent(rows, (d) => d.users);
    if (xDomain[0] === xDomain[1]) {
      xDomain[0] = Math.max(0, xDomain[0] - 1);
      xDomain[1] = xDomain[1] + 1;
    }
    const x = d3.scaleLinear().domain(xDomain).nice().range([c.margin.left, c.width - c.margin.right]);
    const y = d3.scaleLinear().domain([0, d3.max(rows, (d) => d[metric]) || 1]).nice().range([c.height - c.margin.bottom, c.margin.top]);
    addAxes(c.svg, x, y, c, yLabel);
    const line = d3.line().x((d) => x(d.users)).y((d) => y(d[metric]));
    const bySeries = d3.group(rows, (d) => d.mode);
    for (const [series, values] of bySeries) {
      c.svg.append("path").datum(values.sort((a, b) => a.users - b.users)).attr("fill", "none").attr("stroke", colorFor(series)).attr("stroke-width", 3).attr("d", line);
      c.svg
        .selectAll(`circle.${series}-${metric}`)
        .data(values)
        .join("circle")
        .attr("cx", (d) => x(d.users))
        .attr("cy", (d) => y(d[metric]))
        .attr("r", 4)
        .attr("fill", colorFor(series))
        .on("mousemove", (event, d) =>
          showTip(event, {
            ...d,
            metricLabel: options.metricLabel || yLabel,
            seriesLabel: labelFor(series),
            value: valueFormatter(d[metric]),
          })
        )
        .on("mouseleave", hideTip);
    }
    legend(c, Array.from(bySeries.keys()), null, labelFor, colorFor);
  }

  function barChart(selector, rows, metric, label, valueFormatter) {
    const c = chartFrame(selector);
    const x = d3.scaleBand().domain(rows.map((d) => `${d.mode} ${d.users}u`)).range([c.margin.left, c.width - c.margin.right]).padding(0.24);
    const y = d3.scaleLinear().domain([0, d3.max(rows, (d) => d[metric]) || 1]).nice().range([c.height - c.margin.bottom, c.margin.top]);
    addAxes(c.svg, x, y, c, label);
    c.svg.selectAll("rect").data(rows).join("rect").attr("x", (d) => x(`${d.mode} ${d.users}u`)).attr("y", (d) => y(d[metric])).attr("width", x.bandwidth()).attr("height", (d) => y(0) - y(d[metric])).attr("fill", (d) => (d[metric] > 0 ? colors.red : colors.sync)).on("mousemove", (event, d) => showTip(event, { ...d, value: valueFormatter(d[metric]) })).on("mouseleave", hideTip);
  }

  function lifecycleChart(selector, rows) {
    const c = chartFrame(selector);
    if (!rows.length) return emptyChart(c.svg, c.width, c.height);
    const keys = ["preRunP95", "runP95"];
    const x = d3.scaleBand().domain(rows.map((d) => `${d.users}u`)).range([c.margin.left, c.width - c.margin.right]).padding(0.25);
    const y = d3.scaleLinear().domain([0, d3.max(rows, (d) => (d.preRunP95 || 0) + (d.runP95 || 0)) || 1]).nice().range([c.height - c.margin.bottom, c.margin.top]);
    addAxes(c.svg, x, y, c, "P95 seconds");
    const stacked = d3.stack().keys(keys)(rows);
    c.svg.selectAll("g.stack").data(stacked).join("g").attr("fill", (d) => (d.key === "preRunP95" ? colors.preRun : colors.run)).selectAll("rect").data((d) => d).join("rect").attr("x", (d) => x(`${d.data.users}u`)).attr("y", (d) => y(d[1])).attr("height", (d) => y(d[0]) - y(d[1])).attr("width", x.bandwidth());
    legend(c, ["pre-run", "run"], null, (name) => name, (name) => (name === "pre-run" ? colors.preRun : colors.run));
  }

  function statusChart(selector, rows) {
    const c = chartFrame(selector);
    if (!rows.length) return emptyChart(c.svg, c.width, c.height);
    const statuses = Array.from(new Set(rows.flatMap((d) => Object.keys(d.statuses))));
    const x = d3.scaleBand().domain(rows.map((d) => `${d.users}u`)).range([c.margin.left, c.width - c.margin.right]).padding(0.25);
    const y = d3.scaleLinear().domain([0, d3.max(rows, (d) => d3.sum(statuses, (s) => d.statuses[s] || 0)) || 1]).nice().range([c.height - c.margin.bottom, c.margin.top]);
    const color = d3.scaleOrdinal().domain(statuses).range(["#0f766e", "#b7791f", "#b42318", "#2563eb", "#6b7280"]);
    addAxes(c.svg, x, y, c, "Jobs");
    const stacked = d3.stack().keys(statuses).value((d, key) => d.statuses[key] || 0)(rows);
    c.svg.selectAll("g.status").data(stacked).join("g").attr("fill", (d) => color(d.key)).selectAll("rect").data((d) => d).join("rect").attr("x", (d) => x(`${d.data.users}u`)).attr("y", (d) => y(d[1])).attr("height", (d) => y(d[0]) - y(d[1])).attr("width", x.bandwidth());
    legend(c, statuses, color);
  }

  function addAxes(svg, x, y, c, yLabel) {
    svg.append("g").attr("class", "axis").attr("transform", `translate(0,${c.height - c.margin.bottom})`).call(d3.axisBottom(x).ticks ? d3.axisBottom(x).ticks(5) : d3.axisBottom(x));
    svg.append("g").attr("class", "axis").attr("transform", `translate(${c.margin.left},0)`).call(d3.axisLeft(y).ticks(5));
    svg.append("text").attr("class", "label").attr("x", c.margin.left).attr("y", 14).text(yLabel);
  }

  function latencySeriesLabel(mode) {
    if (mode === "sync") return "sync /run response";
    if (mode === "async") return "async /job submit";
    return mode;
  }

  function legend(c, names, colorScale, labelFor = (name) => name, colorFor = null) {
    c.legendNode
      .selectAll(".legend-item")
      .data(names)
      .join("div")
      .attr("class", "legend-item")
      .html(
        (name) => `
          <span class="legend-swatch" style="background:${colorFor ? colorFor(name) : colorScale ? colorScale(name) : colors[name]}"></span>
          <span>${escapeHtml(labelFor(name))}</span>
        `
      );
  }

  function emptyChart(svg, width, height) {
    svg.append("text").attr("x", width / 2).attr("y", height / 2).attr("text-anchor", "middle").attr("class", "label").text("No data available");
  }

  function setupHeaderTooltips() {
    d3.selectAll("[data-help]")
      .on("mousemove", (event) => showTip(event, event.currentTarget.dataset.help))
      .on("mouseleave", hideTip);
  }

  function showTip(event, d) {
    const html =
      typeof d === "string"
        ? escapeHtml(d)
        : `${escapeHtml(d.seriesLabel || d.mode || "")} ${escapeHtml(d.users || "")} users<br>${escapeHtml(d.metricLabel || "value")}: ${escapeHtml(d.value || "")}`;
    tooltip.style("opacity", 1).style("left", `${event.clientX}px`).style("top", `${event.clientY}px`).html(html);
  }

  function hideTip() {
    tooltip.style("opacity", 0);
  }

  function escapeHtml(value) {
    return String(value ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  init();
})();
