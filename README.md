# 🤖 OSCAR Testing with the Robot Framework

 Welcome to the OSCAR Test Suite. This repository provides an automated testing suite built with the Robot Framework to validate and monitor the health and functionality of the OSCAR clusters.

## 🚀 Getting Started

### 🔧 Prerequisites

Before running the tests, ensure you have the following tools installed:

- Python 3.8+
- Robot Framework
- oidc-agent

To install the required dependencies:

```
pip install -r requirements.txt
```

### 🧑‍💻 Setting Up the Configuration File

The test suite uses environment variables to store sensitive information such as  endpoints and credentials.

Create a `.env.yaml` file according to the template shown in `env-template.yaml`

The following information is required:

  - `OSCAR_ENDPOINT`: The endpoint of the OSCAR cluster (e.g. https://mycluster.oscar.grycap.net) 
  - `OSCAR_METRICS`: The endpoint of the OSCAR metrics.
  - `OSCAR_DASHBOARD`: The endpoint of the OSCAR UI (dashboard).
  - `REFRESH_TOKEN`: The OIDC token used to automate the execution of the test suite. In order to get a Refresh Token, you can head to the [Check-in Token Portal](https://aai.egi.eu/token/), click **Authorise** and then **Create Refresh Token** button to generate a new token.
  - `OIDC_AGENT_ACCOUNT`: The short account name of your profile in the [oidc-agent](https://github.com/indigo-dc/oidc-agent) command-line tool from which OIDC-based access tokens will be obtained to authenticate against the OSCAR endpoints.
  - `OIDC_AGENT_PASSWORD`: The password of your [oidc-agent](https://github.com/indigo-dc/oidc-agent) account.



### 🧪 Running Tests

To execute the test cases, simply run the following command:

Run the tests:
```
robot -V variables/.env-template.yaml -d robot_results/ tests/
```

- `.env-template.yaml`: Your YAML file containing the necessary environment variables.
-  `robot_results`: The directory where the output results of the tests will be stored.
-  `tests`: The directory containing the test cases.


This executes all the defined tests. You can also execute a single test suite with:

```
robot -V variables/.env-template.yaml -d robot_results/ tests/oscar-api.robot
```

## 📊 Test Reports and Logs

After running the tests, you’ll get detailed logs and reports in the:

- Report: `report.html` – A high-level test summary
- Log: `log.html` – Detailed execution log for debugging


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