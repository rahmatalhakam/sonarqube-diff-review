#!/usr/bin/env python3
"""Inspect a SonarQube issues report for diff-review readiness."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Dict, Optional, Tuple


def normalize_component(issue: Dict[str, Any]) -> str:
    component = str(issue.get("component") or "")
    project = issue.get("project")

    if project:
        prefix = f"{project}:"
        if component.startswith(prefix):
            return component[len(prefix) :].replace("\\", "/")

    if ":" in component:
        return component.split(":", 1)[1].replace("\\", "/")

    return component.replace("\\", "/")


def issue_line(issue: Dict[str, Any]) -> Any:
    if issue.get("line") is not None:
        return issue.get("line")

    text_range = issue.get("textRange")
    if isinstance(text_range, dict):
        return text_range.get("startLine")

    return None


def load_report(path: Path) -> Dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            payload = json.load(handle)
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid JSON at line {exc.lineno}, column {exc.colno}: {exc.msg}") from exc

    if not isinstance(payload, dict):
        raise ValueError("report root must be a JSON object")

    issues = payload.get("issues")
    if not isinstance(issues, list):
        raise ValueError("report must contain an 'issues' array")

    return payload


def page_coverage(report: Dict[str, Any], issue_count: int) -> Tuple[Optional[int], Optional[int], Optional[int], bool]:
    paging = report.get("paging") if isinstance(report.get("paging"), dict) else {}

    total = paging.get("total", report.get("total"))
    page_index = paging.get("pageIndex", report.get("p", 1))
    page_size = paging.get("pageSize", report.get("ps", issue_count))

    if not all(isinstance(value, int) for value in (total, page_index, page_size)):
        return total, page_index, page_size, False

    covered = page_index * page_size
    return total, page_index, page_size, issue_count >= total or covered >= total


def main() -> int:
    parser = argparse.ArgumentParser(description="Inspect a SonarQube issues JSON report.")
    parser.add_argument("report", help="Path to sonar-issues.json or sonarqube-issues.json")
    args = parser.parse_args()

    report_path = Path(args.report)

    try:
        report = load_report(report_path)
    except OSError as exc:
        print(f"ERROR: cannot read report: {exc}", file=sys.stderr)
        return 1
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    issues = report["issues"]
    total, page_index, page_size, complete = page_coverage(report, len(issues))

    paths = [normalize_component(issue) for issue in issues]
    lines = [issue_line(issue) for issue in issues]
    missing_paths = sum(1 for path in paths if not path)
    missing_lines = sum(1 for line in lines if line is None)
    with_text_range = sum(1 for issue in issues if isinstance(issue.get("textRange"), dict))
    with_flows = sum(1 for issue in issues if issue.get("flows"))
    with_impacts = sum(1 for issue in issues if issue.get("impacts"))

    print(f"Report: {report_path}")
    print(f"Issues loaded: {len(issues)}")
    print(f"Pagination: page={page_index} size={page_size} total={total} complete={str(complete).lower()}")
    print(f"Unique files: {len(set(paths))}")
    print(f"Locations: with_line={len(issues) - missing_lines} missing_line={missing_lines} with_text_range={with_text_range}")
    print(f"Secondary context: with_flows={with_flows} with_impacts={with_impacts}")

    if missing_paths:
        print(f"WARNING: {missing_paths} issues have no usable component path")
    if missing_lines:
        print(f"WARNING: {missing_lines} issues have no primary line or textRange.startLine")
    if not complete:
        print("WARNING: report may be incomplete; fetch all pages before claiming no findings")

    for label, values in (
        ("Types", (issue.get("type") or "UNKNOWN" for issue in issues)),
        ("Severities", (issue.get("severity") or "UNKNOWN" for issue in issues)),
        ("Rules", (issue.get("rule") or "UNKNOWN" for issue in issues)),
        ("Top files", paths),
    ):
        counts = Counter(values)
        rendered = ", ".join(f"{name}={count}" for name, count in counts.most_common(10))
        print(f"{label}: {rendered}")

    return 0 if complete and missing_paths == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
