# 🤖 OSCAR Testing with the Robot Framework

 Welcome to the OSCAR Test Suite. This repository provides an automated testing suite built with the Robot Framework to validate and monitor the health and functionality of the OSCAR clusters.

## 🚀 Getting Started

### 🔧 Prerequisites

Before running the tests, ensure you have the following tools installed:

- Python 3.8+
- Robot Framework

To install the required dependencies:

```
pip install -r requirements.txt
```

### 🧑‍💻 Setting Up Environment Variables

The test suite uses environment variables to store sensitive information such as API credentials and endpoints.

Create a `.env.yaml` file according to the template shown in `env-template.yaml`

### 🧪 Running Tests

To execute the test cases, simply run the following command:

```
robot -V .env.yaml -d results tests
```

- `.env.yaml`: Your YAML file containing the necessary environment variables.
-  `results`: The directory where the output results of the tests will be stored.
-  `tests`: The directory containing the test cases.


This executes all the defined tests. You can also execute a single test suite with:

```
robot -V .env-ai4eosc.yaml -d results tests/oscar-api.robot
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