#!/usr/bin/env python3
"""Build a portable OSCAR scalability experiment artifact and publish the viewer."""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from capture_cluster_status import cluster_resources, prune_empty

OSCAR_HUB_BASE_URL = "https://github.com/grycap/oscar-hub/tree/main/crates"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--experiment-dir", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--service", required=True)
    parser.add_argument("--viewer-src", required=True)
    parser.add_argument("--endpoint", required=True)
    return parser.parse_args()


def load_json(path: Path) -> Dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def as_int(value: Any) -> int:
    try:
        return int(float(value or 0))
    except (TypeError, ValueError):
        return 0


def as_float(value: Any) -> Optional[float]:
    if value in {None, "", "N/A"}:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def first_request_row(rows: List[Dict[str, Any]]) -> Dict[str, Any]:
    for row in rows:
        if row.get("Name") != "Aggregated":
            return row
    return rows[0] if rows else {}


def metric_from_locust(summary: Dict[str, Any]) -> Dict[str, Any]:
    locust = summary.get("locust", {})
    totals = locust.get("totals", {})
    row = first_request_row(locust.get("rows", []))
    request_count = as_int(totals.get("request_count"))
    failure_count = as_int(totals.get("failure_count"))
    return {
        "requests": request_count,
        "failures": failure_count,
        "successes": max(request_count - failure_count, 0),
        "failure_rate": failure_count / request_count if request_count else 0.0,
        "requests_per_second": as_float(row.get("Requests/s")),
        "failures_per_second": as_float(row.get("Failures/s")),
        "latency_ms": {
            "avg": as_float(row.get("Average Response Time")),
            "min": as_float(row.get("Min Response Time")),
            "max": as_float(row.get("Max Response Time")),
            "p50": as_float(row.get("50%")),
            "p95": as_float(row.get("95%")),
            "p99": as_float(row.get("99%")),
        },
        "failure_details": locust.get("failures", []),
    }


def artifact_paths(experiment_dir: Path, service: str, mode: str, users: int) -> Dict[str, str]:
    prefix = experiment_dir / f"{service}-{mode}-{users}u"
    candidates = {
        "summary_json": Path(f"{prefix}_summary.json"),
        "summary_markdown": Path(f"{prefix}_summary.md"),
        "locust_html": Path(f"{prefix}.html"),
        "locust_stats_csv": Path(f"{prefix}_stats.csv"),
        "locust_history_csv": Path(f"{prefix}_stats_history.csv"),
        "locust_failures_csv": Path(f"{prefix}_failures.csv"),
        "locust_exceptions_csv": Path(f"{prefix}_exceptions.csv"),
        "locust_json": Path(f"{prefix}_locust.json"),
    }
    return {name: str(path.relative_to(experiment_dir)) for name, path in candidates.items() if path.exists()}


def build_step(experiment_dir: Path, service: str, mode: str, users: int, summary: Dict[str, Any]) -> Dict[str, Any]:
    step: Dict[str, Any] = {
        "mode": mode,
        "users": users,
        "locust": metric_from_locust(summary),
        "artifacts": artifact_paths(experiment_dir, service, mode, users),
    }
    if "jobs" in summary:
        jobs = summary["jobs"]
        step["jobs"] = {
            "total": jobs.get("total", 0),
            "terminal": jobs.get("terminal", 0),
            "unfinished": jobs.get("unfinished", 0),
            "status_counts": jobs.get("status_counts", {}),
            "completion_seconds": jobs.get("completion_seconds", {}),
            "pre_run_seconds": jobs.get("pre_run_seconds", {}),
            "run_seconds": jobs.get("run_seconds", {}),
            "timings": jobs.get("timings", []),
        }
    return step


def discover_steps(experiment_dir: Path, service: str) -> List[Dict[str, Any]]:
    steps: List[Dict[str, Any]] = []
    for mode in ("sync", "async"):
        for path in experiment_dir.glob(f"{service}-{mode}-*u_summary.json"):
            users_text = path.name.removeprefix(f"{service}-{mode}-").removesuffix("u_summary.json")
            try:
                users = int(users_text)
            except ValueError:
                continue
            steps.append(build_step(experiment_dir, service, mode, users, load_json(path)))
    return sorted(steps, key=lambda item: (item["mode"], item["users"]))


def latest_mtime(paths: List[Path]) -> float:
    existing = [path.stat().st_mtime for path in paths if path.exists()]
    return max(existing) if existing else datetime.now().timestamp()


def service_base_name(service: str) -> str:
    return service.rsplit("-", 1)[0] if "-" in service else service


def hub_url(service_base: str) -> Optional[str]:
    if service_base == "simple-test":
        return f"{OSCAR_HUB_BASE_URL}/{service_base}"
    return None


def invocation_resources(steps: List[Dict[str, Any]], service_config: Dict[str, Any]) -> Dict[str, Dict[str, Any]]:
    resources = {}
    for mode in sorted({step["mode"] for step in steps}):
        resources[mode] = {
            "cpu_cores": service_config.get("cpu"),
            "memory_mib": service_config.get("memory_mib"),
            "source": "OSCAR service resource request per invocation",
        }
    return resources


def build_experiment(experiment_dir: Path, service: str, endpoint: str) -> Dict[str, Any]:
    plan_path = experiment_dir / "quota-plan.json"
    cluster_status_path = experiment_dir / "cluster-status.json"
    baseline_path = experiment_dir / "baseline.json"
    async_warmup_path = experiment_dir / "async-warmup.json"
    run_configuration_path = experiment_dir / "run-configuration.json"
    plan = load_json(plan_path) if plan_path.exists() else {}
    cluster_status = load_json(cluster_status_path) if cluster_status_path.exists() else {}
    baseline = load_json(baseline_path) if baseline_path.exists() else {}
    async_warmup = load_json(async_warmup_path) if async_warmup_path.exists() else {}
    run_configuration = load_json(run_configuration_path) if run_configuration_path.exists() else {}
    if cluster_status and not cluster_status.get("resources"):
        cluster_status["resources"] = prune_empty(cluster_resources(cluster_status.get("payload")))
    steps = discover_steps(experiment_dir, service)
    if not steps:
        raise SystemExit(f"No summary files found for service {service!r} in {experiment_dir}")

    mtimes = [experiment_dir / artifact for step in steps for artifact in step.get("artifacts", {}).values()]
    mtimes.extend(
        path
        for path in (plan_path, cluster_status_path, baseline_path, async_warmup_path, run_configuration_path)
        if path.exists()
    )
    created_at = datetime.fromtimestamp(latest_mtime(mtimes)).astimezone().isoformat(timespec="seconds")
    service_config = plan.get("service", {})
    service_base = service_base_name(service)
    quota = plan.get("quota", {})
    limits = plan.get("limits", {})

    return {
        "schema_version": "1.4",
        "experiment_id": service,
        "created_at": created_at,
        "platform": {
            "endpoint": endpoint,
            "quota_source": plan.get("quota_path"),
            "quota_available": plan.get("quota_available", False),
            "quota": {
                "cpu_available_cores": quota.get("cpu_available"),
                "memory_available_mib": quota.get("memory_available_mib"),
                "safe_parallel_capacity": limits.get("safe_parallel"),
                "cpu_parallel_capacity": limits.get("cpu_parallel"),
                "memory_parallel_capacity": limits.get("memory_parallel"),
            },
            "cluster_status": cluster_status,
            "cluster_resources": cluster_status.get("resources", {}),
        },
        "service": {
            "name": service,
            "base": service_base,
            "hub": {
                "name": service_base,
                "url": hub_url(service_base),
            },
            "cpu": service_config.get("cpu"),
            "memory_mib": service_config.get("memory_mib"),
            "resources": {
                "cpu_cores": service_config.get("cpu"),
                "memory_mib": service_config.get("memory_mib"),
            },
            "invocation_resources": invocation_resources(steps, service_config),
        },
        "load_plan": {
            "requested_users": plan.get("requested_users", sorted({step["users"] for step in steps})),
            "effective_users": plan.get("effective_users", sorted({step["users"] for step in steps})),
            "quota_mode": plan.get("mode"),
        },
        "quota_plan": plan,
        "cluster_status": cluster_status,
        "baseline": baseline,
        "async_warmup": async_warmup,
        "run_configuration": run_configuration,
        "steps": steps,
        "artifacts": {
            "quota_plan": str(plan_path.relative_to(experiment_dir)) if plan_path.exists() else None,
            "cluster_status": str(cluster_status_path.relative_to(experiment_dir)) if cluster_status_path.exists() else None,
            "baseline": str(baseline_path.relative_to(experiment_dir)) if baseline_path.exists() else None,
            "async_warmup": str(async_warmup_path.relative_to(experiment_dir)) if async_warmup_path.exists() else None,
            "run_configuration": str(run_configuration_path.relative_to(experiment_dir)) if run_configuration_path.exists() else None,
            "experiment": "experiment.json",
        },
    }


def update_index(experiments_dir: Path, experiment: Dict[str, Any]) -> Dict[str, Any]:
    index_path = experiments_dir / "index.json"
    if index_path.exists():
        index = load_json(index_path)
    else:
        index = {"schema_version": "1.0", "experiments": []}

    entry = {
        "id": experiment["experiment_id"],
        "file": f"{experiment['experiment_id']}/experiment.json",
        "directory": experiment["experiment_id"],
        "created_at": experiment["created_at"],
        "service": experiment["service"]["name"],
        "endpoint": experiment["platform"].get("endpoint"),
        "users": experiment["load_plan"]["effective_users"],
        "quota_safe_parallel": experiment["platform"]["quota"].get("safe_parallel_capacity"),
    }
    existing = [item for item in index.get("experiments", []) if item.get("id") != entry["id"]]
    existing.append(entry)
    index["experiments"] = sorted(existing, key=lambda item: item.get("created_at", ""), reverse=True)
    write_json(index_path, index)
    return index


def copy_viewer(viewer_src: Path, viewer_dst: Path) -> None:
    if viewer_dst.exists():
        shutil.rmtree(viewer_dst)
    shutil.copytree(viewer_src, viewer_dst)


def publish_viewer_data(viewer_dir: Path, index: Dict[str, Any], experiments_dir: Path) -> None:
    experiments = []
    for entry in index.get("experiments", []):
        path = experiments_dir / entry["file"]
        if path.exists():
            experiments.append(load_json(path))

    data_dir = viewer_dir / "data"
    data_dir.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema_version": "1.0",
        "index": index,
        "experiments": experiments,
    }
    content = "window.OSCAR_SCALABILITY_DATA = " + json.dumps(payload, indent=2, sort_keys=True) + ";\n"
    (data_dir / "experiments.js").write_text(content, encoding="utf-8")


def main() -> int:
    args = parse_args()
    experiment_dir = Path(args.experiment_dir)
    output_root = Path(args.output_root)
    viewer_src = Path(args.viewer_src)
    experiments_dir = output_root / "experiments"
    viewer_dst = output_root / "viewer"

    experiment = build_experiment(experiment_dir, args.service, args.endpoint)
    experiment_path = experiment_dir / "experiment.json"
    write_json(experiment_path, experiment)
    index = update_index(experiments_dir, experiment)
    copy_viewer(viewer_src, viewer_dst)
    publish_viewer_data(viewer_dst, index, experiments_dir)

    print(
        json.dumps(
            {
                "experiment": str(experiment_path),
                "viewer": str(viewer_src / "index.html"),
                "published_viewer": str(viewer_dst / "index.html"),
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
