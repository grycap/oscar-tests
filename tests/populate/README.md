# OSCAR Metrics Population Suite

This folder contains a Robot suite that populates a newly deployed OSCAR cluster with several `cowsay` services, one exposed nginx service, and one shared `cowsay` service visible to both test users. It invokes them so sync, async, exposed, and multi-user-per-service metrics counters increase.

The suite creates deterministic service names:

```text
metrics-populate-simple-<run-id>-00
metrics-populate-simple-<run-id>-01
metrics-populate-simple-<run-id>-02
metrics-populate-simple-<run-id>-03
metrics-populate-exposed-<run-id>
metrics-populate-shared-<run-id>
```

Even-numbered `cowsay` services are created and invoked as `oscaruser00`. Odd-numbered `cowsay` services are created and invoked as `oscaruser01`. The exposed nginx service is created and invoked as `oscaruser01` by default. The shared service is created by `oscaruser00` with `visibility=restricted`, includes both users in `allowed_users`, and is invoked by both users.

## Requirements

Use an auth variables file that configures both Keycloak users. The existing file is:

```bash
variables/.env-auth-keycloak-oscarusers.yaml
```

You also need to pass the target cluster variables file, as with the rest of the OSCAR tests.

## Populate and Leave Services Running

This is the default mode. It creates four `cowsay` services, one exposed nginx service, and one shared service. Each numbered `cowsay` service is invoked twice synchronously and twice asynchronously. The exposed service is invoked twice through `/system/services/{service}/exposed`. The shared service is invoked once synchronously and once asynchronously by each user. Services are left in the cluster.

```bash
robot \
  -V variables/.env-auth-keycloak-oscarusers.yaml \
  -V variables/.env-cluster-<cluster>.yaml \
  tests/populate/populate-metrics.robot
```

The suite prints the generated `POPULATE_RUN_ID` to the console. Keep that value if you want to delete the same batch later.

## Use a Known Run ID

Use this when you want predictable service names.

```bash
robot \
  -V variables/.env-auth-keycloak-oscarusers.yaml \
  -V variables/.env-cluster-<cluster>.yaml \
  --variable POPULATE_RUN_ID:demo01 \
  tests/populate/populate-metrics.robot
```

## Change Service and Invocation Counts

The default service count is `4`. Use `3` if you want only three services.

```bash
robot \
  -V variables/.env-auth-keycloak-oscarusers.yaml \
  -V variables/.env-cluster-<cluster>.yaml \
  --variable POPULATE_SERVICE_COUNT:3 \
  --variable POPULATE_SYNC_INVOCATIONS:5 \
  --variable POPULATE_ASYNC_INVOCATIONS:5 \
  --variable POPULATE_EXPOSED_INVOCATIONS:5 \
  --variable POPULATE_SHARED_SYNC_INVOCATIONS:2 \
  --variable POPULATE_SHARED_ASYNC_INVOCATIONS:2 \
  tests/populate/populate-metrics.robot
```

## Populate and Cleanup at the End

Use this mode to generate metrics activity but remove services before the suite exits.

```bash
robot \
  -V variables/.env-auth-keycloak-oscarusers.yaml \
  -V variables/.env-cluster-<cluster>.yaml \
  --variable POPULATE_CLEANUP:True \
  tests/populate/populate-metrics.robot
```

## Delete a Previous Batch

Use the same run id and service count used during population.

```bash
robot \
  -V variables/.env-auth-keycloak-oscarusers.yaml \
  -V variables/.env-cluster-<cluster>.yaml \
  --variable POPULATE_DELETE_ONLY:True \
  --variable POPULATE_RUN_ID:demo01 \
  tests/populate/populate-metrics.robot
```

If the original run used a non-default service count, include it:

```bash
--variable POPULATE_SERVICE_COUNT:3
```

## Main Variables

| Variable | Default | Meaning |
| --- | --- | --- |
| `POPULATE_RUN_ID` | generated | Suffix used to name the services. |
| `POPULATE_SERVICE_COUNT` | `4` | Number of services to create/delete. |
| `POPULATE_SYNC_INVOCATIONS` | `2` | Sync `/run/{service}` calls per service. |
| `POPULATE_ASYNC_INVOCATIONS` | `2` | Async `/job/{service}` calls per service. |
| `POPULATE_EXPOSED_INVOCATIONS` | `2` | Exposed endpoint calls for the nginx service. |
| `POPULATE_SHARED_SYNC_INVOCATIONS` | `1` | Sync calls to the shared service per user. |
| `POPULATE_SHARED_ASYNC_INVOCATIONS` | `1` | Async calls to the shared service per user. |
| `POPULATE_CLEANUP` | `False` | Delete services at suite teardown. |
| `POPULATE_DELETE_ONLY` | `False` | Only delete services for `POPULATE_RUN_ID`. |
| `POPULATE_SERVICE_PREFIX` | `metrics-populate-simple` | Prefix for generated service names. |
| `POPULATE_EXPOSED_PREFIX` | `metrics-populate-exposed` | Prefix for the generated exposed service name. |
| `POPULATE_EXPOSED_USER_INDEX` | `1` | User selector for the exposed service. `0` uses `oscaruser00`; `1` uses `oscaruser01`. |
| `POPULATE_SHARED_PREFIX` | `metrics-populate-shared` | Prefix for the shared service name. |
| `POPULATE_SHARED_OWNER_INDEX` | `0` | User selector for the shared service owner. |
| `POPULATE_SHARED_OTHER_INDEX` | `1` | User selector for the second user allowed to see and invoke the shared service. |
