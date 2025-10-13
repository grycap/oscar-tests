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

The test suite uses environment variables to store sensitive information such as  endpoints and credentials.

Create a `.env.yaml` file according to the template shown in `env-template.yaml`

The following information is required:

  - `OSCAR_ENDPOINT`: The endpoint of the OSCAR cluster (e.g. https://mycluster.oscar.grycap.net) 
  - `OSCAR_METRICS`: The endpoint of the OSCAR metrics.
  - `OSCAR_DASHBOARD`: The endpoint of the OSCAR UI (dashboard).
  - `BASIC_USER:`: Base64-encoded information of the authentication for the 'oscar' user (echo -n "oscar:password"  | base64)
  - `EGI_AAI_URL`: The base URL of the EGI AAI (Authentication and Authorisation Infrastructure) server.
      - For the production server, use `https://aai.egi.eu`.
      - For the demo server, use `https://aai-demo.egi.eu`.
  - `REFRESH_TOKEN`: The OIDC token used to automate the execution of the test suite. In order to get a Refresh Token, head to the [Check-in Token Portal](https://aai.egi.eu/token/) or [Demo Check-in Token Portal](https://aai-demo.egi.eu/token/), click **Authorise** and then **Create Refresh Token** button to generate a new token.
  - `EGI_VO`: The virtual organization used to test the OSCAR cluster.
  - `FIRST_USER`: User ID
  - `FIRST_USER_ID`: Get the first 10 characters of FIRST_USER (e.g. FIRST_USER: 1234567890987654321 -> FIRST_USER_ID: 1234567890) 
  - `REFRESH_TOKEN_SECOND_USER`: The OIDC token of the second user used to automate the execution
  - `SECOND_USER`: User ID of the second user
  - `SECOND_USER_ID`: Get the first 10 characters of SECOND_USER



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

```
robot -V variables/.env.yaml -d robot_results/ tests/api/service-lifecycle.robot
```

If you are testing an OSCAR deployment in localhost, you can override SSL verification via:

```sh
robot -V variables/.env-localhost.yaml -v SSL_VERIFY:False -v LOCAL_TESTING:True -d robot_results tests/api/service-lifecycle.robot
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
