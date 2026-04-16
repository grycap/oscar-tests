#!/usr/bin/env python3
"""Write non-secret run configuration metadata for a scalability experiment."""

from __future__ import annotations

import argparse
import json
import os
import shlex
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    parser.add_argument("--endpoint", required=True)
    parser.add_argument("--service", required=True)
    parser.add_argument("--experiment-dir", required=True)
    parser.add_argument("--variable", action="append", default=[], help="Experiment variable as NAME=VALUE. Can be repeated.")
    return parser.parse_args()


def parse_variables(items: List[str]) -> Dict[str, Any]:
    variables: Dict[str, Any] = {}
    for item in items:
        if "=" not in item:
            continue
        key, value = item.split("=", 1)
        variables[key] = coerce_value(value)
    return variables


def coerce_value(value: str) -> Any:
    normalized = value.strip()
    if normalized.lower() == "true":
        return True
    if normalized.lower() == "false":
        return False
    if normalized.lower() in {"none", "null"}:
        return None
    return value


def env(name: str) -> str:
    return os.getenv(name, "").strip()


def make_command() -> str:
    auth_goal = env("OSCAR_TEST_AUTH_GOAL")
    cluster_goal = env("OSCAR_TEST_CLUSTER_GOAL")
    suite = env("OSCAR_TEST_ROBOT_SUITE")
    robot_args = env("OSCAR_TEST_ROBOT_ARGS")
    parts = [shlex.quote(item) for item in ["make", "test", auth_goal, cluster_goal] if item]
    if suite:
        parts.append(f"ROBOT_SUITE={shlex.quote(suite)}")
    if robot_args:
        parts.append(f"ROBOT_ARGS={shlex.quote(robot_args)}")
    output_dir = env("OSCAR_TEST_ROBOT_OUTPUT_DIR")
    if output_dir and output_dir != "robot_results":
        parts.append(f"ROBOT_OUTPUT_DIR={shlex.quote(output_dir)}")
    if not auth_goal or not cluster_goal:
        return ""
    return " ".join(parts)


def robot_command() -> str:
    robot = env("OSCAR_TEST_ROBOT") or "robot"
    auth_file = env("OSCAR_TEST_AUTH_FILE")
    cluster_file = env("OSCAR_TEST_CLUSTER_FILE")
    robot_args = env("OSCAR_TEST_ROBOT_ARGS")
    output_dir = env("OSCAR_TEST_ROBOT_OUTPUT_DIR") or "robot_results"
    suite = env("OSCAR_TEST_ROBOT_SUITE")
    parts = [shlex.quote(robot)]
    if auth_file:
        parts.extend(["-V", shlex.quote(auth_file)])
    if cluster_file:
        parts.extend(["-V", shlex.quote(cluster_file)])
    if robot_args:
        parts.append(robot_args)
    parts.extend(["-d", shlex.quote(output_dir)])
    if suite:
        parts.append(shlex.quote(suite))
    return " ".join(parts)


def build_payload(args: argparse.Namespace) -> Dict[str, Any]:
    variables = parse_variables(args.variable)
    return {
        "schema_version": "1.0",
        "captured_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "description": "Non-secret configuration values captured to make the experiment reproducible.",
        "endpoint": args.endpoint.rstrip("/"),
        "service": args.service,
        "experiment_dir": args.experiment_dir,
        "make": {
            "auth_goal": env("OSCAR_TEST_AUTH_GOAL") or None,
            "cluster_goal": env("OSCAR_TEST_CLUSTER_GOAL") or None,
            "auth_file": env("OSCAR_TEST_AUTH_FILE") or None,
            "cluster_file": env("OSCAR_TEST_CLUSTER_FILE") or None,
            "robot": env("OSCAR_TEST_ROBOT") or "robot",
            "robot_suite": env("OSCAR_TEST_ROBOT_SUITE") or None,
            "robot_args": env("OSCAR_TEST_ROBOT_ARGS") or None,
            "robot_output_dir": env("OSCAR_TEST_ROBOT_OUTPUT_DIR") or None,
        },
        "commands": {
            "make": make_command(),
            "robot": robot_command(),
        },
        "variables": variables,
        "notes": [
            "Authentication files and cluster variable files are referenced by path only; their contents are not embedded.",
            "Bearer tokens and credentials are intentionally not captured.",
            "The command is reconstructed from Makefile metadata when the suite is launched through make.",
        ],
    }


def main() -> int:
    args = parse_args()
    payload = build_payload(args)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
