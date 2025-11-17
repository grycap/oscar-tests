# 🤖 OSCAR Testing with the Robot Framework

 Welcome to the OSCAR Test Suite. This repository provides an automated testing suite built with the Robot Framework to validate and monitor the health and functionality of the OSCAR clusters.

## 🚀 Getting Started

### 🔧 Prerequisites

Before running the tests, ensure you have the following tools installed:

- [Python 3.8+](https://www.python.org/)
- [Robot Framework](https://robotframework.org/)
- [oscar-cli](https://github.com/grycap/oscar-cli)
- [oscar-python](https://github.com/grycap/oscar_python/)

To install the required dependencies:

```
pip install -r requirements.txt
```

### 📦 Installing oscar-cli
`oscar-cli` is a Go-based tool and must be installed separately.

You can install it by following the [documentation](https://docs.oscar.grycap.net/oscar-cli/#download).

### 🧑‍💻 Setting Up the Configuration File

The test suite uses environment variables to store sensitive information such as endpoints and credentials. I'd recommend that you have two environment files. The first includes the cluster information, and the second contains the authentication process credentials. This way, you can switch between authentication processes such as EGI-CheckIn or Keycloak. Also, you can create one environment file that contains all the information.

Create a `.env.yaml` file according to the template shown in `env-template.yaml`

The following information is required about the cluster information:
  - `OSCAR_ENDPOINT`: The endpoint of the OSCAR cluster (e.g. https://mycluster.oscar.grycap.net) 
  - `OSCAR_METRICS`: The endpoint of the OSCAR metrics.
  - `OSCAR_DASHBOARD`: The endpoint of the OSCAR UI (dashboard).
  - `BASIC_USER:`: Base64-encoded information of the authentication for the 'oscar' user (echo -n "oscar:password"  | base64)

The next parameters are required to configure the authentication process:
  - `AUTHENTICATION_PROCESS`: This parameter selects the authentication process between EGI `resources/token-egi.resource` and Keycloak `resources/token-keycloak.resource`. **ALWAYS REQUIRED**.
  - `AAI_URL`: The URL token of the AAI (Authentication and Authorisation Infrastructure) server. **ALWAYS REQUIRED**.
      - For the EGI production server, use `https://aai.egi.eu/auth/realms/egi`.
      - For the EGI demo server, use `https://aai-demo.egi.eu/auth/realms/egi`.
  - `AAI_GROUP`: The virtual organization used to test the OSCAR cluster. **ALWAYS REQUIRED**.
  - `CLIENT_ID`: Client ID of Keycloak. Only needed in Keycloak.
  - `SCOPE`: Scope of Keycloak. Only needed in Keycloak.
  - `REFRESH_TOKEN`: The OIDC token used to automate the execution of the test suite. In order to get a Refresh Token, head to the [Check-in Token Portal](https://aai.egi.eu/token/) or [Demo Check-in Token Portal](https://aai-demo.egi.eu/token/), click **Authorise** and then **Create Refresh Token** button to generate a new token. Only used in EGI.
  - `KEYCLOAK_USERNAME` and `KEYCLOAK_PASSWORD`: The user/password Keycloak authentication. Only used in Keycloak.

In case you are testing isolation or visibility, you have to add a second user:
  - `OTHER_REFRESH_TOKEN`: The OIDC token of the second user used to automate the execution.
  - `KEYCLOAK_USERNAME_AUX` and `KEYCLOAK_PASSWORD_AUX`: The user/password of a second user in Keycloak.

In case you are testing the mount feat using an external OSCAR cluster add,:
  - `OSCAR_EXTERNAL`: Endpoint of an external OSCAR cluster.
  - `MINIO_EXTERNAL`: MinIO endpoint of external OSCAR cluster.
  - `MINIO_SECRET_KEY`: Secret Key of `FIRST_USER` used the `MINIO_EXTERNAL`.


### 🧪 Running Tests

To execute the test cases, simply run the following command:

Run the tests:
```
robot -V variables/.env.yaml -d robot_results/ tests/
```

- `.env.yaml`: Your YAML file containing the necessary environment variables.
-  `robot_results`: The directory where the output results of the tests will be stored.
-  `tests`: The directory containing the test cases.


This executes all the defined tests. You can also execute a single test suite with:

```sh
robot -V variables/.env-template.yaml -d robot_results/ tests/api/service-lifecycle.robot
```

#### Dashboard UI suites

Dashboard-specific UI suites live under `tests/dashboard/`, with one file per panel (e.g., `services.robot`, `buckets.robot`, `notebooks.robot`, `info.robot`). Run them all at once or target a panel:

```sh
# Run every dashboard panel test
robot -V variables/.env.yaml -d robot_results/ tests/dashboard

# Execute only the Services panel suite
robot -V variables/.env.yaml -d robot_results/ tests/dashboard/services.robot
```

Execute test using two credential files by splitting the Authentication process (EGI and Keycloak) from the cluster configuration: 

```sh
robot -V  [ variables/env-template-egi.yaml | variables/env-template-keycloak.yaml ] -V variables/env-template-cluster.yaml  -d robot_results/ tests/api/service-lifecycle.robot
```

If you are testing an OSCAR deployment in localhost, you can override SSL verification via:

```sh
robot -V variables/.env-localhost.yaml -v SSL_VERIFY:False -v LOCAL_TESTING:True -d robot_results tests/api/service-lifecycle.robot
```

You can run stress tests with [Locust](https://locust.io) via:
```sh
robot -V variables/.env-cluster.yaml -d robot_results tests/locust/stress-locust.robot
````

### 🧰 Using the Makefile Helper

The repository ships with a `Makefile` that auto-discovers the available credentials and cluster configuration files in `variables/`. It provides a guided interface for running the Robot suites.

- Show the built-in help (also runs when you execute `make` without arguments):
  ```sh
  make
  ```
- List the discovered authentication and cluster targets:
  ```sh
  make list
  ```
- Launch a test run by combining the desired auth and cluster targets (keep the `auth-` prefix; the `cluster-` prefix is optional):
  ```sh
  make test auth-<auth-config> <cluster-config>
  ```
  This resolves to:
  ```sh
  robot -V variables/.env-auth-keycloak-oscaruser00.yaml \
        -V variables/.env-cluster-sandbox.yaml \
        -d robot_results \
        tests/api/service-lifecycle.robot
  ```
- Override the Robot suite (or any Robot options) via the provided make variables:
  ```sh
  make test auth-<auth-config> <cluster-config> \
    ROBOT_SUITE=tests/api/isolation.robot \
    ROBOT_OUTPUT_DIR=robot_results/isolation
  ```
- Run every `.robot` suite automatically:
  ```sh
  make test auth-<auth-config> <cluster-config> ROBOT_SUITE=all
  ```
  Each suite is executed separately with results stored under `robot_results/<suite-name>/`.

You can see the results of the stress test with:
```sh
open "$(ls -t robot_results/locust/*.html | head -1)"    # macOS
# or
xdg-open "$(ls -t robot_results/locust/*.html | head -1)" # Linux
```

### 🧪 Local kind Deployment Workflow

Use `tests/deployment/local-kind.robot` to provision an OSCAR cluster on your workstation (via `oscar/deploy/kind-deploy.sh --devel`) and immediately reuse the existing API/service lifecycle suite against it.

1. Install Docker, kind, kubectl, and git, and ensure the deploy script can run locally.
2. (Optional) Inspect `variables/env-template-kind-local.yaml` to see which variables are populated automatically.
3. Launch the workflow (it clones the `devel` branch of [grycap/oscar](https://github.com/grycap/oscar) into a temporary folder unless you point it to an existing checkout):
   ```sh
   robot tests/deployment/local-kind.robot
   # or reuse a local OSCAR checkout
   robot -v OSCAR_PATH:/path/to/oscar tests/deployment/local-kind.robot
   # keep the cluster around if the suite fails
   robot -v KEEP_CLUSTER_ON_FAILURE:True tests/deployment/local-kind.robot
   ```

Behind the scenes the suite:
- Executes the deploy script and parses the reported cluster/context names, the exposed `http://localhost:8080` endpoint, and the generated OSCAR credentials.
- Generates `variables/.env-kind-local.yaml` (ignored by Git) that points to `resources/token-local.resource`, sets `LOCAL_TESTING: True`, and stores the Basic auth header derived from the script output.
- Waits until `http://localhost:8080/health` is reachable, then repeatedly runs the `ready`-tagged subset of the service lifecycle suite until the cluster can successfully create and invoke a service, and only then executes the full `tests/api/service-lifecycle.robot`, storing artifacts under `robot_results/local-kind`.
- Attempts to delete the temporary kind cluster and removes the generated variable file even if the run fails.

> ℹ️ `resources/token-local.resource` supplies Basic-auth headers so the API tests can run without contacting an external AAI.

If you only need to validate the parsing logic (without bringing up a cluster), use the synthetic fixture test:
```sh
robot tests/deployment/local-kind-parsing.robot
```

## 📊 Test Reports and Logs

After running the tests, you’ll get detailed logs and reports in the:

- Report: `report.html` – A high-level test summary
- Log: `log.html` – Detailed execution log for debugging

## 🐳 Running Tests with Docker

You can run the test suite inside a Docker container for better portability and reproducibility.

### 🛠️ Build the Docker Image

You can either build your own image or use the prebuilt image from GitHub Container Registry (GHCR).

**Option 1: Build the Docker image locally**

```
docker build -t oscar-tests:latest .
```

**Option 2: Use the prebuilt image from GHCR**

Use the [oscar-tests](https://github.com/orgs/grycap/packages/container/package/oscar-tests) image from GHCR.


These images contain all the necessary dependencies to run the tests (except `oscar-cli`, see note below).

### ▶️ Run All Tests
To run all the test suites:

```
docker run \
  -e ROBOT_OPTIONS="--variablefile variables/.env.yaml --pythonpath ." \
  -v "$PWD":/opt/robotframework/tests:Z \
  --workdir /opt/robotframework/tests \
  ghcr.io/grycap/oscar-tests:latest
```
> 💡 If you built the image locally, replace the image name with `oscar-tests:latest`.

### 🧪 Run a Single Test Suite
To run a specific test suite:

```
docker run \
  -e ROBOT_OPTIONS="--variablefile variables/.env.yaml --pythonpath ." \
  -v "$PWD":/opt/robotframework/tests:Z \
  --workdir /opt/robotframework/tests \
  ghcr.io/grycap/oscar-tests:latest \
  robot tests/<path-to-suite>
```
Replace `<path-to-suite>` with the desired test file.

> ⚠️ Note: `oscar-cli` binary is not included in the Docker image.
> If you're running `oscar-cli.robot`, you must manually install it in the container before running the tests.

You can find more information about the docker options used in this image in the base image documentation [here](https://github.com/ppodgorsek/docker-robot-framework).

## 📖 Documentation

  - [Robot Framework User Guide](https://robotframework.org)
	

## 🙌 Contributing

Feel free to open issues, create pull requests, or improve the documentation.

## 📜 License

This project is licensed under the Apache 2.0 License. See the LICENSE file for details.

## 💬 Contact

For any questions or support, reach out via:
  - GitHub Issues: Create a New Issue

Happy testing! 🎉
