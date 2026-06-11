# SonarQube Diff Triage Reference

Read this file when mapping a SonarQube issue report such as `sonar-issues.json` or `sonarqube-issues.json` to a Git diff or preparing the final review output.

## Expected Inputs

- SonarQube report JSON: A JSON object from `/api/issues/search` with an `issues` array. Common local filenames are `sonar-issues.json` and `sonarqube-issues.json`.
- Changed files: `git diff --name-only --find-renames <base>...HEAD`.
- Changed lines: `git diff --unified=0 --find-renames <base>...HEAD`.

If `paging.total` or top-level `total` is greater than the downloaded page coverage, treat the report as incomplete and say which page range was reviewed. Increase `ps` or download additional pages before claiming the branch is clean.

## Field Mapping

Use these fields when present:

- `issues[].component`: Usually `projectKey:path/to/file`. If `issues[].project` is present and `component` starts with `project + ":"`, strip that exact prefix before matching paths. Fall back to stripping the first colon-delimited prefix only when `project` is unavailable.
- `issues[].line`: Primary one-based line number.
- `issues[].textRange.startLine`: Primary line when `line` is absent.
- `issues[].message`: Human-readable issue text.
- `issues[].rule`: Rule identifier.
- `issues[].severity`: Legacy severity.
- `issues[].impacts[].severity`: Clean Code impact severity when present.
- `issues[].type`: Legacy type such as `BUG`, `VULNERABILITY`, or `CODE_SMELL`.
- `issues[].issueStatus` or `issues[].status`: Current issue state.
- `issues[].flows[].locations[]`: Secondary locations. Use these as supporting context, not as the main match unless the user asks for cross-file flow analysis.

Normalize all paths to Git-style `/` separators. Match case-sensitively unless the repository or platform clearly uses case-insensitive paths.

Run `python scripts/inspect-sonar-report.py <report.json>` when available. It validates the core report shape and prints the same path, pagination, and issue distribution checks this reference expects.

## Changed-Line Matching

Parse hunk headers from `git diff --unified=0`:

```text
@@ -oldStart,oldCount +newStart,newCount @@
```

Map SonarQube line numbers to the new-side ranges only. A finding is in scope when:

- The normalized SonarQube path matches a changed file path.
- The primary issue line is inside a new-side hunk range.

For zero-length new ranges, no new line exists; do not attach line-bound issues to deletion-only hunks.

For file-level issues with no line or text range, include them only when the file changed. Mark confidence as lower because the issue cannot be tied to a specific changed line.

## Report Format

Lead with actionable findings:

```text
[severity] path/to/file.ext:line - rule
Problem: <what SonarQube reported>
Why it is in scope: <changed hunk or file-level reason>
Fix: <specific remediation>
```

Then add a short review note:

- Number of SonarQube issues loaded.
- Number of issues matched to changed lines.
- Number ignored because they were outside the diff.
- Any pagination or base-branch uncertainty.

Do not include tokens, authorization headers, raw API responses, or full URLs that contain secrets.
