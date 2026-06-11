---
name: sonarqube-diff-review
description: Download, inspect, and triage SonarQube issue reports against Git diffs. Use when the agent needs to fetch SonarQube issues, compare them with changed files and changed lines, and report or fix only issues inside the current Git diff.
---

# SonarQube Diff Review

Use this skill to review SonarQube findings only where they intersect the user's current code change.

## Core Rules

- Keep SonarQube tokens out of chat, command output, commits, logs, and shell history whenever possible.
- Require Python 3.8+, Git, curl, and either PowerShell or Bash before running the helper workflow.
- Prefer `SONAR_TOKEN` and `SONAR_URL` environment variables over inline command arguments.
- Stop if the issue report is missing, empty, invalid JSON, incomplete due to pagination, or not shaped like a SonarQube issues response.
- Report only issues whose primary location maps to changed files and changed lines.
- Treat file-level issues without line numbers as relevant only when the file itself changed, and label them as file-level findings.
- Do not modify source code unless the user explicitly asks to fix the findings.

## Workflow

1. Confirm the current directory is inside the target Git repository.
2. Use the base branch provided by the user. If none is provided, infer a likely base such as `origin/main`, `origin/master`, `main`, or `master`; ask only when the base remains ambiguous.
3. Download SonarQube issues with the bundled helper for the current platform, or use an existing report file if the user already provided one:

   ```powershell
   $env:SONAR_TOKEN="squ_xxxxxxxxxxxxxxxxx"
   $env:SONAR_URL="https://sonarqube.example.com/api/issues/search?componentKeys=my-project&inNewCodePeriod=true&issueStatuses=CONFIRMED,OPEN&ps=500&p=1&additionalFields=_all"
   .\scripts\download-sonar-issues.ps1
   ```

   ```bash
   export SONAR_TOKEN="squ_xxxxxxxxxxxxxxxxx"
   export SONAR_URL="https://sonarqube.example.com/api/issues/search?componentKeys=my-project&inNewCodePeriod=true&issueStatuses=CONFIRMED,OPEN&ps=500&p=1&additionalFields=_all"
   ./scripts/download-sonar-issues.sh
   ```

4. If the environment blocks network access, request the required approval and rerun the same helper. Never ask the user to paste the token into chat.
5. Inspect the report shape before diff matching:

   ```bash
   python scripts/inspect-sonar-report.py sonar-issues.json
   ```

   Use the actual report filename. Common names are `sonar-issues.json` and `sonarqube-issues.json`.
6. Generate the changed-file and changed-line context:

   ```bash
   git diff --name-only --find-renames <base>...HEAD
   git diff --unified=0 --find-renames <base>...HEAD
   ```

7. Read [references/sonarqube-diff-triage.md](references/sonarqube-diff-triage.md) before mapping issues to diff hunks or writing the final findings.
8. Produce findings first, ordered by severity and confidence. Include file, line, rule, message, why it applies to the changed code, and the recommended fix.
9. Include a short note for ignored issues, such as counts outside the diff or report pagination limits, without dumping the full SonarQube JSON.

## Helper Inputs

The helpers support:

- `SONAR_TOKEN`: SonarQube token. Prefer this over a command argument.
- `SONAR_URL`: Full SonarQube issues API URL.
- Output filename: defaults to `sonarqube-issues.json` in the Git project root.
- Authentication mode: `basic` by default; use `bearer` only when the server expects bearer authentication.

PowerShell parameters:

```powershell
.\scripts\download-sonar-issues.ps1 -OutputFile sonarqube-issues.json -AuthMode basic
```

Bash arguments:

```bash
./scripts/download-sonar-issues.sh --output sonarqube-issues.json --auth-mode basic
```
