#!/usr/bin/env python3
"""Plan OSCAR scalability load steps from the user's quota."""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import ssl
import sys
import time
import urllib.error
import urllib.request
from typing import Any, Dict, List, Optional


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--endpoint", required=True)
    parser.add_argument("--access-token", default=os.getenv("OSCAR_ACCESS_TOKEN", ""))
    parser.add_argument("--authorization-header", default=os.getenv("OSCAR_AUTHORIZATION_HEADER", ""))
    parser.add_argument("--requested-users", required=True)
    parser.add_argument("--service-cpu", required=True)
    parser.add_argument("--service-memory", required=True)
    parser.add_argument("--mode", default="exploratory", choices=["exploratory", "conservative"])
    parser.add_argument("--ssl-verify", default="true")
    parser.add_argument("--quota-retries", type=int, default=6)
    parser.add_argument("--quota-retry-delay", type=float, default=5.0)
    return parser.parse_args()


def truthy(value: str) -> bool:
    return value.strip().lower() in {"1", "true", "yes", "on"}


def parse_users(value: str) -> List[int]:
    users = sorted({int(item.strip()) for item in value.split(",") if item.strip()})
    return [item for item in users if item > 0]


def parse_cpu(value: Any) -> float:
    text = str(value or "0").strip()
    if text.lower() in {"none", "null", ""}:
        return 0.0
    if text.endswith("m"):
        return float(text[:-1]) / 1000
    amount = float(text)
    # OSCAR quota endpoints may return millicores as plain numbers.
    return amount / 1000 if amount > 128 else amount


def parse_memory_mib(value: Any) -> float:
    text = str(value or "0Mi").strip()
    if text.lower() in {"none", "null", ""}:
        return 0.0
    match = re.match(r"^([0-9.]+)\s*([A-Za-z]+)?$", text)
    if not match:
        return 0.0
    amount = float(match.group(1))
    raw_unit = match.group(2)
    if raw_unit is None and amount >= 1024 * 1024:
        return amount / (1024 * 1024)
    unit = (raw_unit or "Mi").lower()
    factor = {
        "ki": 1 / 1024,
        "k": 1 / 1024,
        "mi": 1,
        "m": 1,
        "gi": 1024,
        "g": 1024,
        "ti": 1024 * 1024,
        "t": 1024 * 1024,
    }.get(unit, 1)
    return amount * factor


def request_json(args: argparse.Namespace, path: str) -> Dict[str, Any]:
    request = urllib.request.Request(f"{args.endpoint.rstrip('/')}{path}")
    request.add_header("Accept", "application/json")
    authorization = auth_header(args)
    if authorization:
        request.add_header("Authorization", authorization)

    context = None
    if not truthy(args.ssl_verify):
        context = ssl._create_unverified_context()  # nosec B323: test tooling supports self-signed clusters.

    with urllib.request.urlopen(request, context=context, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def auth_header(args: argparse.Namespace) -> str:
    if args.authorization_header:
        return args.authorization_header
    if args.access_token:
        return f"Bearer {args.access_token}"
    return ""


def fetch_quotas(args: argparse.Namespace) -> Dict[str, Any]:
    path = "/system/quotas/user"
    errors = []
    attempts = max(args.quota_retries, 1)
    for attempt in range(1, attempts + 1):
        try:
            payload = request_json(args, path)
            return {"path": path, "payload": payload}
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            error = f"{path}: HTTP {exc.code}: {body}"
            errors.append(error)
            if exc.code != 500 or "ClusterQueue" not in body or attempt == attempts:
                break
        except Exception as exc:  # noqa: BLE001 - test utility reports the fallback chain.
            errors.append(f"{path}: {exc}")
            break
        time.sleep(args.quota_retry_delay)
    raise RuntimeError("; ".join(errors))


def limit_from_quota(max_value: float, used_value: float, per_invocation: float) -> Optional[int]:
    if max_value <= 0 or per_invocation <= 0:
        return None
    return max(math.floor(max(max_value - used_value, 0.0) / per_invocation), 0)


def plan_users(requested: List[int], safe_parallel: Optional[int], mode: str) -> List[int]:
    if not requested or safe_parallel is None:
        return requested

    below_or_equal = [item for item in requested if item <= safe_parallel]
    above = [item for item in requested if item > safe_parallel]

    if mode == "conservative":
        return below_or_equal or [max(safe_parallel, 1)]

    effective = below_or_equal or [max(safe_parallel, 1)]
    if above:
        effective.append(above[0])
    return sorted({item for item in effective if item > 0})


def build_plan(args: argparse.Namespace) -> Dict[str, Any]:
    requested = parse_users(args.requested_users)
    service_cpu = parse_cpu(args.service_cpu)
    service_memory_mib = parse_memory_mib(args.service_memory)

    quota = fetch_quotas(args)
    resources = quota["payload"].get("resources", {})
    cpu = resources.get("cpu", {})
    memory = resources.get("memory", {})

    cpu_max = parse_cpu(cpu.get("max"))
    cpu_used = parse_cpu(cpu.get("used"))
    memory_max_mib = parse_memory_mib(memory.get("max"))
    memory_used_mib = parse_memory_mib(memory.get("used"))

    cpu_limit = limit_from_quota(cpu_max, cpu_used, service_cpu)
    memory_limit = limit_from_quota(memory_max_mib, memory_used_mib, service_memory_mib)
    limits = [item for item in (cpu_limit, memory_limit) if item is not None]
    safe_parallel = min(limits) if limits else None
    effective = plan_users(requested, safe_parallel, args.mode)

    return {
        "quota_available": True,
        "quota_path": quota["path"],
        "mode": args.mode,
        "requested_users": requested,
        "effective_users": effective,
        "service": {
            "cpu": service_cpu,
            "memory_mib": service_memory_mib,
        },
        "quota": {
            "cpu_max_raw": cpu.get("max"),
            "cpu_used_raw": cpu.get("used"),
            "cpu_max": cpu_max,
            "cpu_used": cpu_used,
            "cpu_available": max(cpu_max - cpu_used, 0.0),
            "memory_max_raw": memory.get("max"),
            "memory_used_raw": memory.get("used"),
            "memory_max_mib": memory_max_mib,
            "memory_used_mib": memory_used_mib,
            "memory_available_mib": max(memory_max_mib - memory_used_mib, 0.0),
        },
        "limits": {
            "cpu_parallel": cpu_limit,
            "memory_parallel": memory_limit,
            "safe_parallel": safe_parallel,
        },
    }


def fallback_plan(args: argparse.Namespace, reason: str) -> Dict[str, Any]:
    requested = parse_users(args.requested_users)
    return {
        "quota_available": False,
        "reason": reason,
        "mode": args.mode,
        "requested_users": requested,
        "effective_users": requested,
        "service": {
            "cpu": parse_cpu(args.service_cpu),
            "memory_mib": parse_memory_mib(args.service_memory),
        },
    }


def main() -> int:
    args = parse_args()
    try:
        plan = build_plan(args)
    except Exception as exc:  # noqa: BLE001 - quota unavailability should not block a load test.
        plan = fallback_plan(args, str(exc))

    print(json.dumps(plan, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
