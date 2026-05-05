#!/usr/bin/env python3
"""Capture an OSCAR cluster status snapshot for a scalability experiment."""

from __future__ import annotations

import argparse
import json
import os
import ssl
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--endpoint", required=True)
    parser.add_argument("--access-token", default=os.getenv("OSCAR_ACCESS_TOKEN", ""))
    parser.add_argument("--authorization-header", default=os.getenv("OSCAR_AUTHORIZATION_HEADER", ""))
    parser.add_argument("--output", required=True)
    parser.add_argument("--ssl-verify", default=os.getenv("SSL_VERIFY", "true"))
    return parser.parse_args()


def truthy(value: str) -> bool:
    return value.strip().lower() in {"1", "true", "yes", "on"}


def ssl_context(ssl_verify: str) -> Optional[ssl.SSLContext]:
    if truthy(ssl_verify):
        return None
    return ssl._create_unverified_context()  # nosec B323: test tooling supports self-signed clusters.


def decode_payload(raw: str) -> Any:
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


def to_float(value: Any) -> Optional[float]:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def cpu_to_cores(value: Any) -> Optional[float]:
    amount = to_float(value)
    if amount is None:
        return None
    # OSCAR status currently reports these values in millicores despite the field name.
    return amount / 1000 if amount > 128 else amount


def bytes_to_mib(value: Any) -> Optional[float]:
    amount = to_float(value)
    if amount is None:
        return None
    return amount / (1024 * 1024)


def sum_values(values: List[Optional[float]]) -> Optional[float]:
    present = [value for value in values if value is not None]
    if not present:
        return None
    return sum(present)


def cluster_resources(payload: Any) -> Dict[str, Any]:
    if not isinstance(payload, dict):
        return {}

    cluster = payload.get("cluster", {})
    if not isinstance(cluster, dict):
        return {}

    metrics = cluster.get("metrics", {}) if isinstance(cluster.get("metrics"), dict) else {}
    cpu_metrics = metrics.get("cpu", {}) if isinstance(metrics.get("cpu"), dict) else {}
    memory_metrics = metrics.get("memory", {}) if isinstance(metrics.get("memory"), dict) else {}
    gpu_metrics = metrics.get("gpu", {}) if isinstance(metrics.get("gpu"), dict) else {}
    nodes = cluster.get("nodes", []) if isinstance(cluster.get("nodes"), list) else []

    node_cpu_capacity = []
    node_cpu_usage = []
    node_memory_capacity = []
    node_memory_usage = []
    for node in nodes:
        if not isinstance(node, dict):
            continue
        cpu = node.get("cpu", {}) if isinstance(node.get("cpu"), dict) else {}
        memory = node.get("memory", {}) if isinstance(node.get("memory"), dict) else {}
        node_cpu_capacity.append(cpu_to_cores(cpu.get("capacity_cores")))
        node_cpu_usage.append(cpu_to_cores(cpu.get("usage_cores")))
        node_memory_capacity.append(bytes_to_mib(memory.get("capacity_bytes")))
        node_memory_usage.append(bytes_to_mib(memory.get("usage_bytes")))

    return {
        "nodes_count": cluster.get("nodes_count") if cluster.get("nodes_count") is not None else len(nodes),
        "cpu": {
            "total_free_cores": cpu_to_cores(cpu_metrics.get("total_free_cores")),
            "max_free_on_node_cores": cpu_to_cores(cpu_metrics.get("max_free_on_node_cores")),
            "total_capacity_cores": sum_values(node_cpu_capacity),
            "total_used_cores": sum_values(node_cpu_usage),
        },
        "memory": {
            "total_free_mib": bytes_to_mib(memory_metrics.get("total_free_bytes")),
            "max_free_on_node_mib": bytes_to_mib(memory_metrics.get("max_free_on_node_bytes")),
            "total_capacity_mib": sum_values(node_memory_capacity),
            "total_used_mib": sum_values(node_memory_usage),
        },
        "gpu": {
            "total": gpu_metrics.get("total_gpu"),
        },
    }


def prune_empty(value: Any) -> Any:
    if isinstance(value, dict):
        return {key: pruned for key, item in value.items() if (pruned := prune_empty(item)) not in ({}, [], None)}
    if isinstance(value, list):
        return [pruned for item in value if (pruned := prune_empty(item)) not in ({}, [], None)]
    return value


def capture_status(args: argparse.Namespace) -> Dict[str, Any]:
    url = f"{args.endpoint.rstrip('/')}/system/status"
    request = urllib.request.Request(url)
    request.add_header("Accept", "application/json")
    authorization = auth_header(args)
    if authorization:
        request.add_header("Authorization", authorization)

    snapshot: Dict[str, Any] = {
        "captured_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "endpoint": url,
        "available": False,
        "status_code": None,
        "payload": None,
    }

    try:
        with urllib.request.urlopen(request, context=ssl_context(args.ssl_verify), timeout=60) as response:
            body = response.read().decode("utf-8", errors="replace")
            snapshot["available"] = 200 <= response.status < 300
            snapshot["status_code"] = response.status
            snapshot["payload"] = decode_payload(body)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        snapshot["status_code"] = exc.code
        snapshot["payload"] = decode_payload(body)
        snapshot["error"] = f"HTTP {exc.code}"
    except Exception as exc:  # noqa: BLE001 - status capture is informative and should not block the test.
        snapshot["error"] = str(exc)

    snapshot["resources"] = prune_empty(cluster_resources(snapshot.get("payload")))
    return snapshot


def auth_header(args: argparse.Namespace) -> str:
    if args.authorization_header:
        return args.authorization_header
    if args.access_token:
        return f"Bearer {args.access_token}"
    return ""


def main() -> int:
    args = parse_args()
    snapshot = capture_status(args)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(snapshot, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(snapshot, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
