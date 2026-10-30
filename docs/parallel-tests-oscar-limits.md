# Parallel test execution and OSCAR backend limits

Design notes for the `test-parallel` make target, plus an analysis of the
backend-side limits that currently cap how much parallelism is safe to run
against a single OSCAR cluster.

## Goal

Cut the wall-clock time of the API suite run without introducing flakiness.
The current serial run of `make test` takes too long when every suite is
waited on, but running all suites simultaneously against one cluster is not
possible either: some suites temporarily mutate *global* state (quotas), so
they must be isolated.

## Design: `make test-parallel auth-<auth> <cluster>`

Two waves, driven by two Make variables (both overridable on the command
line, e.g. `PARALLEL_API_SUITES="tests/api/foo.robot"`):

1. **Wave 1 — parallel suite list (`PARALLEL_API_SUITES`):** the 17 suites
   that are safe to run concurrently. One Robot process per suite is started
   in the background and all of them are launched at once. Each suite gets:
   - its own output directory: `$(ROBOT_OUTPUT_DIR)/api-<safe-suite-name>>`
     (slashes in the suite path are converted to `-`);
   - a per-suite artifacts directory passed as
     `-v ARTIFACTS_DIR:<out_dir>/artifacts`, so every suite writes its
     mutable artifacts (e.g. `service_file.json`) to a private location
     instead of a shared `data/` path.
2. **Wave 2 — serial suite list (`SERIAL_API_SUITES`):** `quotas-user.robot`
   and `minio-quotas.robot`. These temporarily lower the global (MinIO) or
   per-user Kueue memory quotas; anything else creating services or buckets
   while that happens fails spuriously, so they run one at a time, after
   wave 1 has finished.

Robustness properties:

- The run does **not** stop at the first failed suite. Every worker's exit
  status is collected; at the end the target exits `1` if any suite (either
  wave) failed, with full logs under `ROBOT_OUTPUT_DIR`.
- The target reuses the same auth/cluster validation block as `test`.
- `SHELL := /bin/bash` is set because the recipes use bash-only expansion
  (`${var//\//-}`); with `/bin/sh` pointing at dash this fails with
  "Bad substitution".

### Non-colliding suites

Wave 1 safety relies on two changes:

- **Randomized names.** Suites that previously used fixed service/bucket
  names now generate unique names per run (`Assign Random Service Name`,
  `Assign Random String`). `tests/api/mount_cycle.robot` also assigns unique
  bucket names (`Assign Mount Bucket Names`) so two concurrent runs of the
  same repo (or CI jobs with different suites) cannot fight over
  `robot-test/mount`.
- **Per-suite artifacts.** `${ARTIFACTS_DIR}/service_file.json` replaced the
  shared `${DATA_DIR}/service_file.json` in 10 suites +
  `resources/files.resource` (53 occurrences total), so one suite cannot
  delete or overwrite the service body another suite is about to read.
  `ARTIFACTS_DIR` defaults to `${DATA_DIR}`, keeping `make test` (serial)
  fully compatible.

## What limits parallelism today (backend side)

The first full validation run (all 17 suites at once) gives a baseline:

- Wall-clock time: **975 s** (vs. the much longer serial run).
- Result: **138 passed / 69 failed**.

The failures are dominated by **cluster quota saturation**, not by test
logic:

1. **Kueue per-user memory quota.** Each service deployment goes through
   Kueue. Launching 17 suites at once produces a burst of service creations
   (with heavy `cowsay`-style services spawning on top), which exceeds the
   user memory quota; requests start being rejected, and suites that
   legitimately expected a 201 get 400/500.
2. **MinIO quota/capacity.** Bucket creation and upload handling can also
   hit MinIO-side limits when every suite creates buckets simultaneously.
3. **Not yet worker-limited.** The target currently has no cap on
   concurrent suites (one process per suite, all at once), which guarantees
   the worst-case burst.

## Proposed next steps

- **Mitigation (tests repo, short term):** add a `PAR_JOBS` knob to
  `test-parallel` that only starts at most N wave-1 workers at a time
  (waiting for a slot as workers finish), scheduled either in fixed batches
  or as a rolling worker pool. This directly reduces the deployment burst.
  *Status: pending, first stabilization iteration.*
- **Upstream (OSCAR backend):**
  - Allow the per-user Kueue memory quota to be configured per namespace /
    endpoint so test clusters can be sized for parallel validation runs.
  - Surface a clearer error (or a queueing behavior) when service creation
    is deferred/rejected by Kueue, instead of a generic 400/500 that looks
    like a test failure.
  - Expose (or document) MinIO per-user quota settings so suites touching
    buckets can check headroom instead of racing other users' quota.

## Usage

```sh
# full parallel run
make test-parallel auth-keycloak tfm2

# run with a custom wave composition
make test-parallel auth-keycloak tfm2 PARALLEL_API_SUITES="tests/api/federation.robot"
```

Results per suite land in `robot_results/api-<suite-name>/` (including
`./artifacts/` with that suite's generated service files).
