"""
Locust user definitions for stressing the OSCAR Manager API.

Environment variables consumed:
    OSCAR_ACCESS_TOKEN -> Bearer token used for authenticated endpoints.
    OSCAR_SERVICE_NAME -> Target service name (defaults to robot-test-cowsay).
    LOCUST_WAIT_MIN    -> Minimum wait time between tasks (seconds, default 1).
    LOCUST_WAIT_MAX    -> Maximum wait time between tasks (seconds, default 3).
"""

import os
from typing import Dict

from locust import HttpUser, between, task


def _build_headers() -> Dict[str, str]:
    """Build common headers for API requests."""
    access_token = os.getenv("OSCAR_ACCESS_TOKEN", "").strip()
    if access_token:
        authorization = f"Bearer {access_token}"
    else:
        # Falling back to basic auth allows running in limited environments.
        authorization = os.getenv("OSCAR_BASIC_AUTH", "").strip()
        if authorization and not authorization.lower().startswith("basic "):
            authorization = f"Basic {authorization}"

    headers: Dict[str, str] = {
        "Accept": "application/json",
        "Content-Type": "application/json",
    }

    if authorization:
        headers["Authorization"] = authorization

    return headers


HEADERS = _build_headers()


class OscarApiUser(HttpUser):
    """Locust user exercising key OSCAR API endpoints."""

    wait_time = between(
        float(os.getenv("LOCUST_WAIT_MIN", "1")),
        float(os.getenv("LOCUST_WAIT_MAX", "3")),
    )

    _service_name = os.getenv("OSCAR_SERVICE_NAME", "robot-test-cowsay")

    @task(3)
    def get_health(self) -> None:
        self.client.get("/health", name="GET /health", headers=HEADERS)

    @task(2)
    def list_services(self) -> None:
        self.client.get("/system/services", name="GET /system/services", headers=HEADERS)

    @task(2)
    def read_service(self) -> None:
        self.client.get(
            f"/system/services/{self._service_name}",
            name="GET /system/services/:name",
            headers=HEADERS,
        )

    @task
    def get_system_config(self) -> None:
        self.client.get(
            "/system/config",
            name="GET /system/config",
            headers=HEADERS,
        )

    @task
    def get_system_status(self) -> None:
        self.client.get(
            "/system/status",
            name="GET /system/status",
            headers=HEADERS,
        )
