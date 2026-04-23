"""
Locust user definitions for OSCAR service invocation scalability tests.

Environment variables consumed:
    OSCAR_SERVICE_NAME   -> Target service name.
    OSCAR_INVOCATION_AUTHORIZATION_HEADER -> Full Authorization header for /run and /job.
    OSCAR_AUTHORIZATION_HEADER -> Fallback Authorization header for /run and /job.
    OSCAR_ACCESS_TOKEN   -> Fallback user bearer token used for /run and /job.
    OSCAR_LOAD_MODE      -> sync, async, or mixed.
    SCALABILITY_PAYLOAD  -> Request body sent to the service.
    SCALABILITY_BASE64_PAYLOAD -> Base64-encode payload before sending.
    LOCUST_WAIT_MIN      -> Minimum wait time between tasks.
    LOCUST_WAIT_MAX      -> Maximum wait time between tasks.
"""

import base64
import binascii
import os
import random
import uuid
from typing import Dict

from locust import HttpUser, between, task


def _build_headers() -> Dict[str, str]:
    authorization = os.getenv("OSCAR_INVOCATION_AUTHORIZATION_HEADER", "").strip()
    fallback_authorization = os.getenv("OSCAR_AUTHORIZATION_HEADER", "").strip()
    access_token = os.getenv("OSCAR_ACCESS_TOKEN", "").strip()

    headers: Dict[str, str] = {
        "Accept": "text/plain, application/json",
        "Content-Type": os.getenv("SCALABILITY_CONTENT_TYPE", "text/plain"),
    }

    if authorization:
        headers["Authorization"] = authorization
    elif fallback_authorization:
        headers["Authorization"] = fallback_authorization
    elif access_token:
        headers["Authorization"] = f"Bearer {access_token}"

    return headers


HEADERS = _build_headers()
SERVICE_NAME = os.getenv("OSCAR_SERVICE_NAME", "simple-test")
LOAD_MODE = os.getenv("OSCAR_LOAD_MODE", "sync").strip().lower()
PAYLOAD = os.getenv("SCALABILITY_PAYLOAD", "The quick brown fox jumped over the lazy dog")


def _decoded_response_text(text: str) -> str:
    try:
        return base64.b64decode(text.strip(), validate=True).decode("utf-8", errors="replace")
    except (binascii.Error, ValueError):
        return text


class OscarInvocationUser(HttpUser):
    """Locust user invoking an OSCAR service through /run and/or /job."""

    wait_time = between(
        float(os.getenv("LOCUST_WAIT_MIN", "0")),
        float(os.getenv("LOCUST_WAIT_MAX", "0")),
    )

    @task
    def invoke_service(self) -> None:
        mode = LOAD_MODE
        if mode == "mixed":
            sync_weight = int(os.getenv("OSCAR_SYNC_WEIGHT", "1"))
            async_weight = int(os.getenv("OSCAR_ASYNC_WEIGHT", "1"))
            population = (["sync"] * sync_weight) + (["async"] * async_weight)
            mode = random.choice(population)

        if mode == "async":
            self._invoke_async()
        else:
            self._invoke_sync()

    def _payload(self) -> str:
        payload = PAYLOAD
        if os.getenv("SCALABILITY_UNIQUE_PAYLOAD", "true").lower() in {"1", "true", "yes"}:
            payload = f"{payload}\nrequest_id={uuid.uuid4()}"
        if os.getenv("SCALABILITY_BASE64_PAYLOAD", "true").lower() in {"1", "true", "yes"}:
            return base64.b64encode(payload.encode("utf-8")).decode("ascii")
        return payload

    def _invoke_sync(self) -> None:
        with self.client.post(
            f"/run/{SERVICE_NAME}",
            data=self._payload(),
            headers=HEADERS,
            name="POST /run/:service",
            catch_response=True,
        ) as response:
            if response.status_code != 200:
                response.failure(f"expected 200, got {response.status_code}: {response.text[:200]}")
            else:
                decoded_text = _decoded_response_text(response.text)
                if "Words:" not in decoded_text and "Characters:" not in decoded_text:
                    response.failure("sync response does not contain simple-test analysis output")

    def _invoke_async(self) -> None:
        with self.client.post(
            f"/job/{SERVICE_NAME}",
            data=self._payload(),
            headers=HEADERS,
            name="POST /job/:service",
            catch_response=True,
        ) as response:
            if response.status_code != 201:
                response.failure(f"expected 201, got {response.status_code}: {response.text[:200]}")
