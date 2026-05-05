# OSCAR Scalability Tests

This directory contains the Locust-based scalability and API stress suites for OSCAR.

```text
tests/scalability/
  scalability.robot          # Service invocation scalability experiment
  stress-api.robot           # OSCAR Manager API stress suite
  src/                       # Python helpers used by the Robot suites
  viewer/                    # Static D3 viewer template
```

The main scalability suite creates a temporary `simple-test-*` service and measures both synchronous and asynchronous invocations under increasing load. Each run produces a portable experiment JSON file and publishes a static D3 viewer that can display one or more experiments.

## Quick Start

Run a full scalability experiment with the Makefile helper:

```sh
make test auth-keycloak-gmolto cluster-localhost \
  ROBOT_SUITE=tests/scalability/scalability.robot \
  ROBOT_ARGS="-v SCALABILITY_USERS:1,2,4 -v SCALABILITY_RUN_TIME:30s -v SCALABILITY_SPAWN_RATE:1 -v SCALABILITY_ASYNC_SETTLE_TIME:60s"
```

Open the static viewer:

```sh
open tests/scalability/viewer/index.html
```

The suite also prints the exact experiment artifact and viewer paths at the end of the run:

```text
OSCAR scalability experiment artifact: .../robot_results/scalability/experiments/simple-test-xxxx/experiment.json
OSCAR scalability viewer: .../tests/scalability/viewer/index.html
OSCAR scalability published viewer copy: .../robot_results/scalability/viewer/index.html
```

## What The Test Does

The scalability suite performs these steps:

1. Configures the selected authentication mode for OSCAR Manager operations: OIDC bearer token for the test user, or Basic auth for the OSCAR `oscar` user.
2. Creates a dedicated experiment directory under `robot_results/scalability/experiments/<experiment-id>/`.
3. Records the OSCAR cluster endpoint configured by the selected cluster variables.
4. Captures the initial cluster resource snapshot from `/system/status`.
5. Creates a temporary `simple-test-*` OSCAR service with the selected manager authentication mode.
6. Configures invocation authentication for `POST /run/{service}` and `POST /job/{service}`.
7. Computes a load plan, optionally using the user's quota from `/system/quotas/user`.
8. Measures isolated first-ready and warm baseline invocations before Locust starts.
9. Writes non-secret run configuration metadata for reproducibility.
10. Runs one Locust step per configured user count for synchronous invocations through `POST /run/{service}`.
11. Submits asynchronous warm-up jobs before the measured async load steps.
12. Runs one Locust step per configured user count for asynchronous submissions through `POST /job/{service}`.
13. Waits `SCALABILITY_ASYNC_SETTLE_TIME` after each async step.
14. Queries OSCAR Manager job data from `GET /system/logs/{service}` using the manager authentication mode.
15. Writes per-step summaries, a normalized experiment JSON, and a D3 static viewer.
16. Deletes the temporary service and jobs unless cleanup variables are disabled.

Direct HTTP invocation payloads are base64-encoded by default in the Locust client, matching the format used by `oscar-cli service run --text-input`.

Manager API calls and service invocations can use different credentials. In `SCALABILITY_AUTH_MODE:user`, the OIDC user bearer token is used for both manager API calls and invocations. In `SCALABILITY_AUTH_MODE:oscar`, the suite uses `BASIC_USER` from the cluster file for manager API calls, then reads the generated service token from `GET /system/services/{service}` and uses that token for `POST /run/{service}` and `POST /job/{service}`. Tokens and credentials are never written to the experiment artifacts.

## Invocation Modes

The suite measures two different behaviors:

| Mode | Endpoint | What It Measures |
| --- | --- | --- |
| `sync` | `POST /run/{service}` | End-user synchronous response time, throughput, and HTTP failures. |
| `async` | `POST /job/{service}` | Job submission latency and, through OSCAR Manager logs, pre-run time, run time, completion time, and final job states. |

For asynchronous calls, the HTTP response time only measures job acceptance. The end-to-end processing time is derived from OSCAR Manager timestamps:

```text
pre_run_seconds = start_time - creation_time
run_seconds = finish_time - start_time
completion_seconds = finish_time - creation_time
```

`pre_run_seconds` is deliberately broad. It measures the interval from job creation until OSCAR reports execution start, so it can include OSCAR controller reconciliation, Kueue admission, Kubernetes scheduling, image handling, and container startup. It should not be read as only "waiting because there were no free CPU or memory resources".

## Invocation Baseline

Before the Locust load steps, the suite can measure isolated baseline invocations:

- First ready synchronous invocation through `POST /run/{service}`.
- Warm synchronous invocation through a second immediate `POST /run/{service}`.
- First ready asynchronous submission through `POST /job/{service}` plus job completion timing from OSCAR Manager logs.
- Warm asynchronous submission through a second immediate `POST /job/{service}` plus job completion timing.

This baseline is useful to compare isolated behavior against the load-test results. It is not a guaranteed node-level cold-start measurement. The suite waits until OSCAR reports the service as ready, and it does not control Docker image cache state on Kubernetes nodes.

Some OSCAR deployments can expose the service token before the synchronous `/run/{service}` path is ready to accept traffic. To avoid recording that short readiness race as the baseline result, the synchronous baseline retries transient `502`, `503`, and `504` responses before giving up. The default retry window is controlled by `SCALABILITY_BASELINE_SYNC_RETRIES` and `SCALABILITY_BASELINE_SYNC_RETRY_INTERVAL`. When retries are used, `baseline.json` records the number of attempts, total elapsed time, and the failed transient attempts.

The baseline is printed to the console and saved as:

```text
robot_results/scalability/experiments/<experiment-id>/baseline.json
```

## Async Warm-Up And Submit Pacing

Before measured async Locust steps, the suite can submit a small number of warm-up jobs and wait for them to complete. This isolates short startup effects in OSCAR, Kueue, Kubernetes scheduling, image handling, and the service runtime from the measured async load steps.

The warm-up result is saved as:

```text
robot_results/scalability/experiments/<experiment-id>/async-warmup.json
```

Async Locust steps also have their own wait interval. This prevents the async submit rate from being driven only by how quickly OSCAR accepts `/job` requests. With the default async wait of one second, each Locust user waits one second between async job submissions. Sync steps continue to use `LOCUST_WAIT_MIN` and `LOCUST_WAIT_MAX`.

## Reproducibility Metadata

Each experiment stores the non-secret configuration values used to launch the run:

```text
robot_results/scalability/experiments/<experiment-id>/run-configuration.json
```

This file includes:

- The reconstructed `make test ...` command when the suite is launched through the Makefile helper.
- The equivalent Robot command.
- Referenced authentication and cluster variable file paths.
- The OSCAR endpoint and generated service name.
- The scalability variables that shape the experiment, such as `SCALABILITY_USERS`, `SCALABILITY_RUN_TIME`, `SCALABILITY_SERVICE_CPU`, `SCALABILITY_SERVICE_MEMORY`, `SCALABILITY_QUOTA_MODE`, and baseline settings.

Bearer tokens and credential contents are not stored. Authentication and cluster files are referenced by path only.

## Quota-Aware Load Planning

By default, the suite reads the user's quota after creating the temporary service:

```text
GET /system/quotas/user
```

The service is created first because OSCAR/Kueue deployments may create the per-user `ClusterQueue` lazily on the first authenticated service operation. If the quota endpoint temporarily reports that the `ClusterQueue` is missing, the helper retries before falling back to the requested load steps unchanged.

The quota values are normalized to CPU cores and MiB, then used to estimate a safe parallel capacity:

```text
cpu_parallel = floor(available_cpu_cores / SCALABILITY_SERVICE_CPU)
memory_parallel = floor(available_memory_mib / SCALABILITY_SERVICE_MEMORY)
safe_parallel = min(cpu_parallel, memory_parallel)
```

The effective load plan depends on `SCALABILITY_QUOTA_MODE`:

| Mode | Behavior |
| --- | --- |
| `exploratory` | Keeps requested steps up to the safe capacity and the first requested step above it. This is useful to expose saturation points. |
| `conservative` | Removes requested steps above the estimated safe capacity. This is useful for smoke or CI runs. |

The plan is printed to the console and saved as:

```text
robot_results/scalability/experiments/<experiment-id>/quota-plan.json
```

Example console output:

```text
OSCAR scalability experiment
Service: simple-test-dbl3 (1.0 CPU, 265Mi; parsed 1.0 CPU, 265.0 MiB)
Requested user steps: 1,2,4
Effective user steps: 1,2,4
Run time per step: 30s; spawn rate: 1; async settle: 60s
Cluster resources from /system/status: nodes=3; total_free_cpu=7.4 cores; max_node_free_cpu=3.1 cores; total_free_memory=18432.0 MiB; max_node_free_memory=8192.0 MiB
Quota source: /system/quotas/user
Quota raw max: cpu=2000, memory=2147483648
Available quota: cpu=2.0 cores, memory=2048.0 MiB
Estimated parallel capacity: cpu=20, memory=16, safe=16; mode=exploratory
```

## Configuration Variables

### Understanding `SCALABILITY_USERS`

`SCALABILITY_USERS` is a comma-separated list of Locust concurrent-user steps, not a list of OSCAR user accounts. For example, `SCALABILITY_USERS:1,2,4` means the suite will run one step with 1 concurrent Locust user, then one with 2 concurrent Locust users, then one with 4 concurrent Locust users.

Each Locust user repeatedly invokes the same temporary `simple-test-*` service during the configured `SCALABILITY_RUN_TIME`. Higher values therefore increase the number of concurrent client-side invocation loops against OSCAR:

- In `sync` mode, each Locust user sends synchronous `POST /run/{service}` requests and waits for the service response.
- In `async` mode, each Locust user submits asynchronous jobs through `POST /job/{service}`. The suite later queries OSCAR Manager logs to derive pre-run, run, and completion timings.
- `SCALABILITY_USERS` is quota-aware when `SCALABILITY_USE_QUOTAS=True`: the requested list may be reduced or extended according to `SCALABILITY_QUOTA_MODE` and the estimated safe parallel capacity.
- The values are not equivalent to exact Kubernetes pod concurrency. They are the offered client load. Actual parallel execution depends on OSCAR scheduling, service resources, user quotas, cold starts, and cluster capacity.

### Understanding `SCALABILITY_SPAWN_RATE`

`SCALABILITY_SPAWN_RATE` is the Locust user ramp-up speed, expressed in users per second. The suite passes it directly to Locust as `-r`:

```text
locust ... -u <users> -r <SCALABILITY_SPAWN_RATE> -t <SCALABILITY_RUN_TIME>
```

It does not set requests per second. It only controls how quickly each Locust step reaches its target concurrency from `SCALABILITY_USERS`. For example, with `SCALABILITY_USERS:1,2,4`, `SCALABILITY_SPAWN_RATE:1`, and `SCALABILITY_RUN_TIME:30s`:

- The 1-user step reaches its target in about 1 second.
- The 2-user step reaches its target in about 2 seconds.
- The 4-user step reaches its target in about 4 seconds.

The remaining time in each step is the steady-state part of the measurement. If the target user count is high and the spawn rate is low, ramp-up can consume a large part of the configured run time. For example, a 32-user step with `SCALABILITY_SPAWN_RATE:1` takes about 32 seconds to reach 32 users, so a `SCALABILITY_RUN_TIME:30s` step may never spend meaningful time at full target concurrency.

Use a low spawn rate when you want a gradual load increase and less abrupt pressure on OSCAR. Use a higher spawn rate when you want each step to reach the target concurrency quickly and measure mostly steady load. For small exploratory runs such as `SCALABILITY_USERS:1,2,4`, values of `1` or `2` are usually enough. For larger runs such as `1,2,4,8,16,32`, consider increasing either `SCALABILITY_SPAWN_RATE` or `SCALABILITY_RUN_TIME` so the largest steps have enough time at full concurrency.

Common variables:

| Variable | Default | Description |
| --- | --- | --- |
| `SCALABILITY_AUTH_MODE` | `user` | `user` uses the configured OIDC user bearer token for manager calls and invocations. `oscar` uses Basic auth from `BASIC_USER` in the cluster file for manager calls and the generated service token for `/run` and `/job`. |
| `SCALABILITY_USERS` | `1,2,4` | Requested Locust concurrent-user steps. |
| `SCALABILITY_SPAWN_RATE` | `1` | Locust user ramp-up speed in users per second. |
| `SCALABILITY_RUN_TIME` | `30s` | Duration of each Locust step. |
| `SCALABILITY_ASYNC_SETTLE_TIME` | `60s` | Time to wait after async load before collecting job status and timings. |
| `SCALABILITY_ASYNC_WAIT_MIN` | `1` | Minimum seconds each async Locust user waits between `/job` submissions. |
| `SCALABILITY_ASYNC_WAIT_MAX` | `1` | Maximum seconds each async Locust user waits between `/job` submissions. |
| `SCALABILITY_SERVICE_CPU` | `1.0` | CPU requested by the temporary `simple-test` service. |
| `SCALABILITY_SERVICE_MEMORY` | `265Mi` | Memory requested by the temporary `simple-test` service. |
| `SCALABILITY_USE_QUOTAS` | `True` | Enables quota-aware load planning. |
| `SCALABILITY_QUOTA_MODE` | `exploratory` | `exploratory` or `conservative`. |
| `SCALABILITY_SYNC_ENABLED` | `True` | Enables synchronous steps. |
| `SCALABILITY_ASYNC_ENABLED` | `True` | Enables asynchronous steps. |
| `SCALABILITY_BASELINE_ENABLED` | `True` | Enables isolated first-ready and warm invocation measurements before Locust. |
| `SCALABILITY_BASELINE_SYNC_RETRIES` | `15` | Additional retries for synchronous baseline calls when `/run/{service}` returns transient `502`, `503`, or `504` responses. |
| `SCALABILITY_BASELINE_SYNC_RETRY_INTERVAL` | `2` | Seconds to wait between synchronous baseline retry attempts. |
| `SCALABILITY_BASELINE_ASYNC_TIMEOUT` | `120` | Maximum seconds to wait for each baseline async job to reach a terminal state. |
| `SCALABILITY_BASELINE_ASYNC_POLL_INTERVAL` | `2` | Seconds between OSCAR Manager log polls for baseline async jobs. |
| `SCALABILITY_ASYNC_WARMUP_ENABLED` | `True` | Enables asynchronous warm-up jobs before measured async Locust steps. |
| `SCALABILITY_ASYNC_WARMUP_JOBS` | `3` | Number of asynchronous warm-up jobs to submit and wait for. |
| `SCALABILITY_ASYNC_WARMUP_SUBMIT_INTERVAL` | `1` | Seconds to wait between async warm-up job submissions. |
| `SCALABILITY_CLEAN_JOBS` | `True` | Deletes jobs before async steps and during teardown. |
| `SCALABILITY_CLEAN_SERVICE` | `True` | Deletes the temporary service during teardown. |

Example with a larger exploratory run:

```sh
make test auth-keycloak-gmolto cluster-localhost \
  ROBOT_SUITE=tests/scalability/scalability.robot \
  ROBOT_ARGS="-v SCALABILITY_USERS:1,2,4,8,16,32 -v SCALABILITY_RUN_TIME:1m -v SCALABILITY_SPAWN_RATE:2 -v SCALABILITY_ASYNC_SETTLE_TIME:180s -v SCALABILITY_QUOTA_MODE:exploratory"
```

Example conservative run:

```sh
make test auth-keycloak-gmolto cluster-localhost \
  ROBOT_SUITE=tests/scalability/scalability.robot \
  ROBOT_ARGS="-v SCALABILITY_USERS:1,2,4,8,16,32 -v SCALABILITY_QUOTA_MODE:conservative"
```

Example run with the OSCAR `oscar` Basic-auth user configured in the cluster file:

```sh
make test auth-keycloak-gmolto cluster-eosc-dc \
  ROBOT_SUITE=tests/scalability/scalability.robot \
  ROBOT_ARGS="-v SCALABILITY_AUTH_MODE:oscar -v SCALABILITY_USERS:1,2,4 -v SCALABILITY_SERVICE_CPU:1.0 -v SCALABILITY_SERVICE_MEMORY:256Mi"
```

`SCALABILITY_AUTH_MODE:oscar` does not store credentials in the experiment artifacts. The generated `run-configuration.json` records only the selected mode and the referenced config file paths.

## Output Artifacts

The suite writes raw and normalized results under:

```text
robot_results/scalability/experiments/<experiment-id>/
```

Per-step Locust artifacts:

```text
<experiment-id>-sync-1u.html
<experiment-id>-sync-1u_stats.csv
<experiment-id>-sync-1u_stats_history.csv
<experiment-id>-sync-1u_failures.csv
<experiment-id>-sync-1u_exceptions.csv
<experiment-id>-sync-1u_locust.json

<experiment-id>-async-1u.html
...
```

Per-step summaries:

```text
<experiment-id>-sync-1u_summary.json
<experiment-id>-sync-1u_summary.md
<experiment-id>-async-1u_summary.json
<experiment-id>-async-1u_summary.md
```

Experiment artifacts:

```text
robot_results/scalability/experiments/<experiment-id>/experiment.json
robot_results/scalability/experiments/<experiment-id>/quota-plan.json
robot_results/scalability/experiments/<experiment-id>/cluster-status.json
robot_results/scalability/experiments/<experiment-id>/baseline.json
robot_results/scalability/experiments/<experiment-id>/async-warmup.json
robot_results/scalability/experiments/<experiment-id>/run-configuration.json
robot_results/scalability/experiments/index.json
robot_results/scalability/viewer/index.html
robot_results/scalability/viewer/data/experiments.js
```

The `<experiment-id>/experiment.json` file is the canonical result for one experiment. It includes:

- Experiment metadata.
- OSCAR cluster endpoint.
- Deployed OSCAR service metadata, including the OSCAR Hub URL for `simple-test`.
- Per-invocation CPU and memory requested by the service for the executed invocation modes.
- The quota plan captured before the workload starts.
- The initial `/system/status` cluster resource snapshot.
- The isolated invocation baseline captured before Locust starts.
- The async warm-up jobs captured before measured async Locust steps.
- The run configuration metadata required to reproduce the test inputs.
- Service resources.
- Requested and effective load plan.
- Synchronous and asynchronous step metrics.
- Async job lifecycle timings and final statuses.
- References to raw Locust and summary files.

The canonical viewer template lives in `tests/scalability/viewer/`. The generated data file lives under `robot_results/scalability/viewer/data/experiments.js`, and the template loads it through a relative path. A portable copy of the viewer is still published into `robot_results/scalability/viewer/` on each run.

## Cleaning Results

Remove previous scalability experiments, Locust reports, stress API reports, and generated viewer data with:

```sh
make clean-scalability-results
```

This deletes:

```text
robot_results/scalability/
```

Remove all Robot Framework results with:

```sh
make clean-results
```

This deletes:

```text
robot_results/
```

Both cleanup targets honor `ROBOT_OUTPUT_DIR` if it is overridden.

## Viewing Results

Open the static D3 viewer:

```sh
open tests/scalability/viewer/index.html
```

The viewer can display one or more experiment JSON files listed in:

```text
robot_results/scalability/experiments/index.json
```

It currently shows:

- Experiment overview.
- Platform baseline split into deployed service resources, cluster resource data from `/system/status`, and user quota data from `/system/quotas/user`.
- Invocation baseline for first-ready and warm isolated calls.
- Automatically generated key findings.
- Step-by-step summary table.
- Throughput vs load.
- Invocation P95 latency.
- HTTP failure rate.
- Async job pre-run and run P95 timings.
- Job status composition.
- Header tooltips explaining the main table metrics.
- Reproducibility command captured when the experiment was launched.

Because the viewer loads `robot_results/scalability/viewer/data/experiments.js` directly, it can be opened from the source tree without copying result files into `tests/scalability/viewer/` and without running a web server.

## Rebuilding The Experiment Viewer

If raw artifacts already exist, rebuild the experiment JSON and republish the viewer with:

```sh
python3 tests/scalability/src/build_experiment.py \
  --experiment-dir robot_results/scalability/experiments/<experiment-id> \
  --output-root robot_results/scalability \
  --service <service-name> \
  --viewer-src tests/scalability/viewer \
  --endpoint <oscar-endpoint>
```

For example:

```sh
python3 tests/scalability/src/build_experiment.py \
  --experiment-dir robot_results/scalability/experiments/simple-test-dbl3 \
  --output-root robot_results/scalability \
  --service simple-test-dbl3 \
  --viewer-src tests/scalability/viewer \
  --endpoint https://oscar.example.com
```

## Interpreting Results

For synchronous invocations:

- The invocation baseline shows first-ready and warm isolated `/run` latency before client load is applied.
- Throughput should grow with users until the platform saturates.
- P95/P99 latency jumps indicate pressure even if there are no HTTP failures.
- HTTP `400`, `500`, or timeout failures mark overload or admission problems.

For asynchronous invocations:

- The invocation baseline shows isolated `/job` submit latency and end-to-end job completion timing before client load is applied.
- `POST /job` latency is submission latency, not job completion latency.
- Pre-run time growth indicates delay before OSCAR reports execution start. It may come from controller reconciliation, admission, scheduling, image handling, container startup, or quota pressure.
- Run time growth may indicate execution contention.
- Unfinished jobs after `SCALABILITY_ASYNC_SETTLE_TIME` can mean saturation, or simply that the settle time was too short.
- Job status composition is often more useful than submission latency for detecting async saturation.

For quota-aware experiments:

- If all requested steps are below `safe_parallel`, the run mainly measures behavior within expected capacity.
- In `exploratory` mode, the first step above `safe_parallel` is useful to demonstrate the saturation boundary.
- In `conservative` mode, steps above `safe_parallel` are skipped.

## API Stress Suite

The API stress suite is separate from service invocation scalability:

```sh
make test auth-keycloak-gmolto cluster-localhost \
  ROBOT_SUITE=tests/scalability/stress-api.robot
```

It exercises OSCAR Manager API endpoints through Locust and writes artifacts under:

```text
robot_results/scalability/stress-api/
```

Open the latest stress API Locust report:

```sh
open "$(ls -t robot_results/scalability/stress-api/*.html | head -1)"
```
