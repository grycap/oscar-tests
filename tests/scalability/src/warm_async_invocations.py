#!/usr/bin/env python3
"""Warm the OSCAR asynchronous invocation path before measured Locust steps."""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.parse
from pathlib import Path
from typing import Any, Dict, List

from measure_baseline_invocations import collect_jobs, now, payload, post, truthy, wait_for_job


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
    parser.add_argument("--jobs", type=int, default=3)
    parser.add_argument("--submit-interval", type=float, default=1.0)
    parser.add_argument("--async-timeout", type=float, default=120.0)
    parser.add_argument("--async-poll-interval", type=float, default=2.0)
    return parser.parse_args()


def submit_and_wait(args: argparse.Namespace, index: int) -> Dict[str, Any]:
    label = f"async-warmup-{index}"
    result: Dict[str, Any] = {
        "label": label,
        "started_at": now(),
        "endpoint": f"{args.endpoint.rstrip('/')}/job/{args.service}",
    }
    try:
        before = set(collect_jobs(args))
        monotonic_start = time.monotonic()
        status, response_body, elapsed_ms, response_headers = post(
            args,
            f"/job/{urllib.parse.quote(args.service)}",
            payload(args, label),
        )
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
    except Exception as exc:  # noqa: BLE001 - warm-up should report partial data.
        result.update({"ok": False, "error": str(exc)})
    result["finished_at"] = now()
    return result


def run_warmup(args: argparse.Namespace) -> Dict[str, Any]:
    started = time.monotonic()
    jobs: List[Dict[str, Any]] = []
    submit_interval = max(args.submit_interval, 0.0)
    job_count = max(args.jobs, 0)
    for index in range(1, job_count + 1):
        jobs.append(submit_and_wait(args, index))
        if index < job_count:
            time.sleep(submit_interval)

    ok_count = sum(1 for item in jobs if item.get("ok"))
    return {
        "schema_version": "1.0",
        "captured_at": now(),
        "endpoint": args.endpoint.rstrip("/"),
        "service": args.service,
        "description": "Asynchronous warm-up jobs submitted before measured Locust async steps.",
        "config": {
            "jobs": job_count,
            "submit_interval_seconds": submit_interval,
            "base64_payload": truthy(args.base64_payload),
            "unique_payload": truthy(args.unique_payload),
            "async_timeout_seconds": args.async_timeout,
            "async_poll_interval_seconds": args.async_poll_interval,
        },
        "summary": {
            "ok": ok_count == job_count,
            "jobs": job_count,
            "succeeded": ok_count,
            "failed": job_count - ok_count,
            "elapsed_seconds": time.monotonic() - started,
        },
        "jobs": jobs,
    }


def main() -> int:
    args = parse_args()
    warmup = run_warmup(args)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(warmup, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(warmup, indent=2, sort_keys=True))
    return 0 if warmup.get("summary", {}).get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
