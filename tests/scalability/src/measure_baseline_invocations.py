#!/usr/bin/env python3
"""Measure isolated OSCAR invocations before the Locust scalability steps."""

from __future__ import annotations

import argparse
import base64
import binascii
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional, Set, Tuple


TERMINAL_STATUSES = {"Succeeded", "Failed"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--endpoint", required=True)
    parser.add_argument("--service", required=True)
    parser.add_argument("--access-token", default=os.getenv("OSCAR_ACCESS_TOKEN", ""))
    parser.add_argument("--authorization-header", default=os.getenv("OSCAR_AUTHORIZATION_HEADER", ""))
    parser.add_argument(
        "--invocation-authorization-header",
        default=os.getenv("OSCAR_INVOCATION_AUTHORIZATION_HEADER", ""),
    )
    parser.add_argument("--payload-file", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--ssl-verify", default=os.getenv("SSL_VERIFY", "true"))
    parser.add_argument("--content-type", default="text/plain")
    parser.add_argument("--base64-payload", default="true")
    parser.add_argument("--unique-payload", default="true")
    parser.add_argument("--sync-retries", type=int, default=15)
    parser.add_argument("--sync-retry-interval", type=float, default=2.0)
    parser.add_argument("--async-timeout", type=float, default=120.0)
    parser.add_argument("--async-poll-interval", type=float, default=2.0)
    return parser.parse_args()


def truthy(value: str) -> bool:
    return value.strip().lower() in {"1", "true", "yes", "on"}


def ssl_context(ssl_verify: str) -> Optional[ssl.SSLContext]:
    if truthy(ssl_verify):
        return None
    return ssl._create_unverified_context()  # nosec B323: test tooling supports self-signed clusters.


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def headers(args: argparse.Namespace) -> Dict[str, str]:
    request_headers = {
        "Accept": "text/plain, application/json",
        "Content-Type": args.content_type,
    }
    authorization = invocation_auth_header(args)
    if authorization:
        request_headers["Authorization"] = authorization
    return request_headers


def manager_auth_header(args: argparse.Namespace) -> str:
    if args.authorization_header:
        return args.authorization_header
    if args.access_token:
        return f"Bearer {args.access_token}"
    return ""


def invocation_auth_header(args: argparse.Namespace) -> str:
    if args.invocation_authorization_header:
        return args.invocation_authorization_header
    return manager_auth_header(args)


def payload(args: argparse.Namespace, label: str) -> bytes:
    text = Path(args.payload_file).read_text(encoding="utf-8")
    if truthy(args.unique_payload):
        text = f"{text.rstrip()}\nrequest_id={label}-{uuid.uuid4()}\n"
    if truthy(args.base64_payload):
        text = base64.b64encode(text.encode("utf-8")).decode("ascii")
    return text.encode("utf-8")


def decode_response_text(text: str) -> str:
    try:
        return base64.b64decode(text.strip(), validate=True).decode("utf-8", errors="replace")
    except (binascii.Error, ValueError):
        return text


def post(args: argparse.Namespace, path: str, body: bytes) -> Tuple[int, str, float, Dict[str, str]]:
    url = f"{args.endpoint.rstrip('/')}{path}"
    request = urllib.request.Request(url, data=body, method="POST")
    for key, value in headers(args).items():
        request.add_header(key, value)

    started = time.perf_counter()
    try:
        with urllib.request.urlopen(request, context=ssl_context(args.ssl_verify), timeout=120) as response:
            response_body = response.read().decode("utf-8", errors="replace")
            elapsed_ms = (time.perf_counter() - started) * 1000
            return response.status, response_body, elapsed_ms, dict(response.headers.items())
    except urllib.error.HTTPError as exc:
        response_body = exc.read().decode("utf-8", errors="replace")
        elapsed_ms = (time.perf_counter() - started) * 1000
        return exc.code, response_body, elapsed_ms, dict(exc.headers.items())


def request_json(args: argparse.Namespace, path: str, params: Optional[Dict[str, str]] = None) -> Dict[str, Any]:
    endpoint = args.endpoint.rstrip("/")
    query = f"?{urllib.parse.urlencode(params)}" if params else ""
    request = urllib.request.Request(f"{endpoint}{path}{query}")
    request.add_header("Accept", "application/json")
    authorization = manager_auth_header(args)
    if authorization:
        request.add_header("Authorization", authorization)
    with urllib.request.urlopen(request, context=ssl_context(args.ssl_verify), timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def collect_jobs(args: argparse.Namespace) -> Dict[str, Dict[str, Any]]:
    all_jobs: Dict[str, Dict[str, Any]] = {}
    page = ""
    while True:
        params = {"page": page} if page else None
        try:
            payload_data = request_json(args, f"/system/logs/{urllib.parse.quote(args.service)}", params=params)
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                return all_jobs
            raise
        all_jobs.update(payload_data.get("jobs", {}))
        page = payload_data.get("next_page") or ""
        if not page:
            break
    return all_jobs


def parse_time(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def seconds_between(start: Optional[datetime], end: Optional[datetime]) -> Optional[float]:
    if not start or not end:
        return None
    return max((end - start).total_seconds(), 0.0)


def job_timing(name: str, job: Dict[str, Any]) -> Dict[str, Any]:
    created = parse_time(job.get("creation_time"))
    started = parse_time(job.get("start_time"))
    finished = parse_time(job.get("finish_time"))
    return {
        "name": name,
        "status": job.get("status", "Unknown"),
        "creation_time": job.get("creation_time"),
        "start_time": job.get("start_time"),
        "finish_time": job.get("finish_time"),
        "pre_run_seconds": seconds_between(created, started),
        "run_seconds": seconds_between(started, finished),
        "completion_seconds": seconds_between(created, finished),
    }


def new_job_name(before: Set[str], jobs: Dict[str, Dict[str, Any]]) -> Optional[str]:
    candidates = sorted(set(jobs) - before)
    if candidates:
        return candidates[-1]
    return None


def should_retry_sync(status: Optional[int]) -> bool:
    return status in {502, 503, 504}


def measure_sync(args: argparse.Namespace, label: str) -> Dict[str, Any]:
    result: Dict[str, Any] = {
        "label": label,
        "started_at": now(),
        "endpoint": f"{args.endpoint.rstrip('/')}/run/{args.service}",
    }
    started = time.perf_counter()
    max_attempts = max(args.sync_retries, 0) + 1
    retry_interval = max(args.sync_retry_interval, 0)
    failures = []

    for attempt in range(1, max_attempts + 1):
        try:
            status, response_body, elapsed_ms, response_headers = post(
                args,
                f"/run/{urllib.parse.quote(args.service)}",
                payload(args, label),
            )
            decoded = decode_response_text(response_body)
            finished_at = now()
            result.update(
                {
                    "finished_at": finished_at,
                    "latency_ms": elapsed_ms,
                    "status_code": status,
                    "ok": status == 200,
                    "response_bytes": len(response_body.encode("utf-8")),
                    "content_type": response_headers.get("Content-Type") or response_headers.get("content-type"),
                    "validated_output": "Words:" in decoded and "Characters:" in decoded,
                    "attempts": attempt,
                    "total_elapsed_ms": (time.perf_counter() - started) * 1000,
                }
            )
            if status == 200:
                break

            failure = {
                "attempt": attempt,
                "finished_at": finished_at,
                "latency_ms": elapsed_ms,
                "status_code": status,
                "response_bytes": len(response_body.encode("utf-8")),
                "retryable": should_retry_sync(status),
            }
            if response_body:
                failure["error"] = response_body[:500]
            failures.append(failure)
            result["error"] = response_body[:500]

            if not should_retry_sync(status) or attempt == max_attempts:
                break
        except Exception as exc:  # noqa: BLE001 - baseline should be reported, not hide partial data.
            result.update(
                {
                    "finished_at": now(),
                    "ok": False,
                    "error": str(exc),
                    "attempts": attempt,
                    "total_elapsed_ms": (time.perf_counter() - started) * 1000,
                }
            )
            failures.append(
                {
                    "attempt": attempt,
                    "finished_at": result["finished_at"],
                    "error": str(exc),
                    "retryable": True,
                }
            )
            if attempt == max_attempts:
                break

        time.sleep(retry_interval)

    if failures:
        result["retry_failures"] = failures
    return result


def wait_for_job(args: argparse.Namespace, before: Set[str], submitted_at: float) -> Dict[str, Any]:
    deadline = submitted_at + args.async_timeout
    selected_name: Optional[str] = None
    last_job: Dict[str, Any] = {}
    polls = 0

    while time.monotonic() < deadline:
        polls += 1
        jobs = collect_jobs(args)
        if selected_name is None:
            selected_name = new_job_name(before, jobs)
        if selected_name and selected_name in jobs:
            last_job = jobs[selected_name]
            if last_job.get("status") in TERMINAL_STATUSES:
                timing = job_timing(selected_name, last_job)
                timing.update({"ok": last_job.get("status") == "Succeeded", "polls": polls, "observed_at": now()})
                return timing
        time.sleep(args.async_poll_interval)

    if selected_name and last_job:
        timing = job_timing(selected_name, last_job)
        timing.update({"ok": False, "polls": polls, "observed_at": now(), "timeout": True})
        return timing
    return {"ok": False, "polls": polls, "observed_at": now(), "timeout": True, "error": "new job was not observed"}


def measure_async(args: argparse.Namespace, label: str) -> Dict[str, Any]:
    result: Dict[str, Any] = {
        "label": label,
        "started_at": now(),
        "endpoint": f"{args.endpoint.rstrip('/')}/job/{args.service}",
    }
    try:
        before = set(collect_jobs(args))
        monotonic_start = time.monotonic()
        status, response_body, elapsed_ms, response_headers = post(args, f"/job/{urllib.parse.quote(args.service)}", payload(args, label))
        result["submit"] = {
            "finished_at": now(),
            "latency_ms": elapsed_ms,
            "status_code": status,
            "ok": status == 201,
            "response_bytes": len(response_body.encode("utf-8")),
            "content_type": response_headers.get("Content-Type") or response_headers.get("content-type"),
        }
        if status != 201:
            result["submit"]["error"] = response_body[:500]
            result["ok"] = False
            return result
        result["job"] = wait_for_job(args, before, monotonic_start)
        result["ok"] = bool(result["submit"]["ok"] and result["job"].get("ok"))
    except Exception as exc:  # noqa: BLE001 - baseline should be reported, not hide partial data.
        result.update({"ok": False, "error": str(exc)})
    result["finished_at"] = now()
    return result


def measure(args: argparse.Namespace) -> Dict[str, Any]:
    return {
        "schema_version": "1.0",
        "captured_at": now(),
        "endpoint": args.endpoint.rstrip("/"),
        "service": args.service,
        "description": "Isolated invocation baseline measured before the Locust load steps.",
        "caveats": [
            "This is not a guaranteed node-level cold start.",
            "The test measures the first invocation after OSCAR reports the service as ready.",
            "Docker image cache state on Kubernetes nodes is not controlled by this test.",
        ],
        "config": {
            "base64_payload": truthy(args.base64_payload),
            "unique_payload": truthy(args.unique_payload),
            "sync_retries": args.sync_retries,
            "sync_retry_interval_seconds": args.sync_retry_interval,
            "async_timeout_seconds": args.async_timeout,
            "async_poll_interval_seconds": args.async_poll_interval,
        },
        "sync": {
            "first_ready": measure_sync(args, "sync-first-ready"),
            "warm": measure_sync(args, "sync-warm"),
        },
        "async": {
            "first_ready": measure_async(args, "async-first-ready"),
            "warm": measure_async(args, "async-warm"),
        },
    }


def main() -> int:
    args = parse_args()
    baseline = measure(args)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(baseline, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(baseline, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
