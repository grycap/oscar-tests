#!/usr/bin/env python3
"""Collect OSCAR scalability results after a Locust step."""

from __future__ import annotations

import argparse
import csv
import json
import os
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from datetime import datetime
from pathlib import Path
from statistics import mean
from typing import Any, Dict, Iterable, List, Optional


TERMINAL_STATUSES = {"Succeeded", "Failed"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--endpoint", required=True)
    parser.add_argument("--service", required=True)
    parser.add_argument("--mode", required=True, choices=["sync", "async", "mixed"])
    parser.add_argument("--locust-prefix", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--markdown", required=True)
    parser.add_argument("--ssl-verify", default=os.getenv("SSL_VERIFY", "true"))
    parser.add_argument("--access-token", default=os.getenv("OSCAR_ACCESS_TOKEN", ""))
    parser.add_argument("--authorization-header", default=os.getenv("OSCAR_AUTHORIZATION_HEADER", ""))
    return parser.parse_args()


def truthy(value: str) -> bool:
    return value.strip().lower() in {"1", "true", "yes", "on"}


def auth_header(args: argparse.Namespace) -> str:
    if args.authorization_header:
        return args.authorization_header
    if args.access_token:
        return f"Bearer {args.access_token}"
    return ""


def request_json(args: argparse.Namespace, path: str, params: Optional[Dict[str, str]] = None) -> Dict[str, Any]:
    endpoint = args.endpoint.rstrip("/")
    query = f"?{urllib.parse.urlencode(params)}" if params else ""
    request = urllib.request.Request(f"{endpoint}{path}{query}")
    request.add_header("Accept", "application/json")
    authorization = auth_header(args)
    if authorization:
        request.add_header("Authorization", authorization)

    context = None
    if not truthy(args.ssl_verify):
        context = ssl._create_unverified_context()  # nosec B323: test tooling supports self-signed clusters.

    try:
        with urllib.request.urlopen(request, context=context, timeout=60) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"GET {path} failed with {exc.code}: {body}") from exc


def collect_jobs(args: argparse.Namespace) -> Dict[str, Any]:
    all_jobs: Dict[str, Dict[str, Any]] = {}
    page = ""
    while True:
        params = {"page": page} if page else None
        payload = request_json(args, f"/system/logs/{urllib.parse.quote(args.service)}", params=params)
        all_jobs.update(payload.get("jobs", {}))
        page = payload.get("next_page") or ""
        if not page:
            break

    statuses = Counter(job.get("status", "Unknown") for job in all_jobs.values())
    timings = [_job_timings(name, job) for name, job in all_jobs.items()]
    completion_times = [item["completion_seconds"] for item in timings if item.get("completion_seconds") is not None]
    pre_run_times = [item["pre_run_seconds"] for item in timings if item.get("pre_run_seconds") is not None]
    run_times = [item["run_seconds"] for item in timings if item.get("run_seconds") is not None]

    return {
        "total": len(all_jobs),
        "status_counts": dict(statuses),
        "terminal": sum(count for status, count in statuses.items() if status in TERMINAL_STATUSES),
        "unfinished": sum(count for status, count in statuses.items() if status not in TERMINAL_STATUSES),
        "timings": timings,
        "completion_seconds": _stats(completion_times),
        "pre_run_seconds": _stats(pre_run_times),
        "run_seconds": _stats(run_times),
    }


def _parse_time(value: Optional[str]) -> Optional[datetime]:
    if not value:
        return None
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def _seconds_between(start: Optional[datetime], end: Optional[datetime]) -> Optional[float]:
    if not start or not end:
        return None
    return max((end - start).total_seconds(), 0.0)


def _job_timings(name: str, job: Dict[str, Any]) -> Dict[str, Any]:
    created = _parse_time(job.get("creation_time"))
    started = _parse_time(job.get("start_time"))
    finished = _parse_time(job.get("finish_time"))
    return {
        "name": name,
        "status": job.get("status", "Unknown"),
        "creation_time": job.get("creation_time"),
        "start_time": job.get("start_time"),
        "finish_time": job.get("finish_time"),
        "pre_run_seconds": _seconds_between(created, started),
        "run_seconds": _seconds_between(started, finished),
        "completion_seconds": _seconds_between(created, finished),
    }


def _stats(values: Iterable[float]) -> Dict[str, Optional[float]]:
    sorted_values = sorted(values)
    if not sorted_values:
        return {"count": 0, "avg": None, "min": None, "max": None, "p50": None, "p95": None, "p99": None}
    return {
        "count": len(sorted_values),
        "avg": mean(sorted_values),
        "min": sorted_values[0],
        "max": sorted_values[-1],
        "p50": _percentile(sorted_values, 50),
        "p95": _percentile(sorted_values, 95),
        "p99": _percentile(sorted_values, 99),
    }


def _percentile(sorted_values: List[float], percentile: int) -> float:
    if len(sorted_values) == 1:
        return sorted_values[0]
    index = round((percentile / 100) * (len(sorted_values) - 1))
    return sorted_values[index]


def collect_locust_stats(prefix: str) -> Dict[str, Any]:
    stats_file = Path(f"{prefix}_stats.csv")
    json_file = Path(f"{prefix}_locust.json")
    if not stats_file.exists():
        return {"stats_file": str(stats_file), "rows": [], "error": "stats file not found"}

    rows: List[Dict[str, Any]] = []
    with stats_file.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            if row.get("Name") == "Aggregated":
                continue
            rows.append(row)

    json_stats = collect_locust_json_stats(json_file)
    totals = json_stats.get("totals") or _locust_totals(rows)
    failures = json_stats.get("failures") or collect_locust_failures(prefix)

    return {
        "stats_file": str(stats_file),
        "json_file": str(json_file),
        "rows": rows,
        "totals": totals,
        "failures": failures,
    }


def collect_locust_json_stats(path: Path) -> Dict[str, Any]:
    if not path.exists():
        return {}

    payload = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(payload, dict):
        stats = payload.get("stats") or payload.get("requests") or []
        errors = payload.get("errors") or []
        total = payload.get("total")
    elif isinstance(payload, list):
        stats = payload
        errors = []
        total = None
    else:
        return {}

    totals = _json_totals(stats, total)
    failures = _json_failures(errors)
    return {"totals": totals, "failures": failures}


def _json_totals(stats: List[Dict[str, Any]], total: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    source = total or next(
        (
            item
            for item in stats
            if str(item.get("name", "")).lower() in {"aggregated", "total"}
            or str(item.get("method", "")).lower() in {"aggregated", "total"}
        ),
        None,
    )
    if source is None:
        source = {
            "num_requests": sum(_int(item.get("num_requests")) for item in stats),
            "num_failures": sum(_int(item.get("num_failures")) for item in stats),
            "avg_content_length": None,
        }

    request_count = _int(source.get("num_requests") or source.get("request_count"))
    failure_count = _int(source.get("num_failures") or source.get("failure_count"))
    return {
        "request_count": request_count,
        "failure_count": failure_count,
        "success_count": max(request_count - failure_count, 0),
        "average_content_size": source.get("avg_content_length") or source.get("average_content_size"),
    }


def _json_failures(errors: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    failures: List[Dict[str, Any]] = []
    for item in errors:
        failures.append(
            {
                "method": item.get("method", ""),
                "name": item.get("name", ""),
                "error": item.get("error") or item.get("message") or "",
                "occurrences": _int(item.get("occurrences") or item.get("count")),
            }
        )
    return failures


def collect_locust_failures(prefix: str) -> List[Dict[str, Any]]:
    failures_file = Path(f"{prefix}_failures.csv")
    if not failures_file.exists():
        return []

    failures: List[Dict[str, Any]] = []
    with failures_file.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            if not any(row.values()):
                continue
            failures.append(
                {
                    "method": row.get("Method", ""),
                    "name": row.get("Name", ""),
                    "error": row.get("Error", ""),
                    "occurrences": _int(row.get("Occurrences")),
                }
            )
    return failures


def _locust_totals(rows: List[Dict[str, str]]) -> Dict[str, Any]:
    request_count = sum(_int(row.get("Request Count")) for row in rows)
    failure_count = sum(_int(row.get("Failure Count")) for row in rows)
    avg_sizes = [_float(row.get("Average Content Size")) for row in rows if row.get("Average Content Size")]
    return {
        "request_count": request_count,
        "failure_count": failure_count,
        "success_count": max(request_count - failure_count, 0),
        "average_content_size": mean(avg_sizes) if avg_sizes else None,
    }


def _int(value: Optional[str]) -> int:
    try:
        return int(float(value or 0))
    except ValueError:
        return 0


def _float(value: Optional[str]) -> float:
    try:
        return float(value or 0)
    except ValueError:
        return 0.0


def write_markdown(summary: Dict[str, Any], path: Path) -> None:
    locust_totals = summary["locust"].get("totals", {})
    lines = [
        f"# OSCAR scalability step: {summary['mode']}",
        "",
        f"- Service: `{summary['service']}`",
        f"- Locust requests: {locust_totals.get('request_count', 0)}",
        f"- Locust failures: {locust_totals.get('failure_count', 0)}",
    ]
    failures = summary["locust"].get("failures", [])
    if failures:
        lines.extend(["", "## Locust Failures", ""])
        lines.extend(f"- {item['occurrences']} x `{item['method']} {item['name']}`: {item['error']}" for item in failures)
    if summary.get("jobs"):
        jobs = summary["jobs"]
        lines.extend(
            [
                f"- Jobs visible through OSCAR Manager: {jobs['total']}",
                f"- Terminal jobs: {jobs['terminal']}",
                f"- Unfinished jobs: {jobs['unfinished']}",
                f"- Job statuses: `{json.dumps(jobs['status_counts'], sort_keys=True)}`",
                "",
                "## Async End-To-End Timings",
                "",
                "| Metric | Count | Avg | P50 | P95 | P99 | Max |",
                "| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
                _timing_row("Completion seconds", jobs["completion_seconds"]),
                _timing_row("Pre-run seconds", jobs["pre_run_seconds"]),
                _timing_row("Run seconds", jobs["run_seconds"]),
            ]
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _timing_row(label: str, stats: Dict[str, Optional[float]]) -> str:
    return (
        f"| {label} | {stats['count']} | {_fmt(stats['avg'])} | {_fmt(stats['p50'])} | "
        f"{_fmt(stats['p95'])} | {_fmt(stats['p99'])} | {_fmt(stats['max'])} |"
    )


def _fmt(value: Optional[float]) -> str:
    return "-" if value is None else f"{value:.3f}"


def main() -> int:
    args = parse_args()
    summary: Dict[str, Any] = {
        "service": args.service,
        "mode": args.mode,
        "locust": collect_locust_stats(args.locust_prefix),
    }
    if args.mode in {"async", "mixed"}:
        summary["jobs"] = collect_jobs(args)

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    write_markdown(summary, Path(args.markdown))
    return 0


if __name__ == "__main__":
    sys.exit(main())
