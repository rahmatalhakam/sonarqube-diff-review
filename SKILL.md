---
name: sonarqube-diff-review
description: Download, inspect, and triage SonarQube issue reports against Git diffs. Use when the agent needs to fetch SonarQube issues, compare them with changed files and changed lines, and report or fix only issues inside the current Git diff.
---

# SonarQube Diff Review

Use this skill to review SonarQube findings only where they intersect the user's current code change.

## Core Rules

- Keep SonarQube tokens out of chat, command output, commits, logs, and shell history whenever possible.
- Read the SonarQube token only from persistent User or Machine environment storage set with `[System.Environment]::SetEnvironmentVariable`. Never use `$env:SONAR_TOKEN`, process `SONAR_TOKEN`, command arguments, prompts, or chat for tokens.
- Require the SonarQube issues API URL as explicit user input to the helper. Never use `$env:SONAR_URL` or process `SONAR_URL`.
- Stop before downloading if the persistent token or explicit URL is missing, and tell the user to set the missing value first.
- Save every generated artifact under `.sonarqube-diff-review/<session-id>/`; do not save reports, temp files, or logs in the repository root.
- Use bearer authentication by default.
- Review and fix only committed code in `<base>...HEAD`; ignore stashed and uncommitted worktree changes.
- Require Python 3.8+, Git, PowerShell/pwsh for persistent token access, and curl when using Bash before running the helper workflow.
- Stop if the issue report is missing, empty, invalid JSON, incomplete due to pagination, or not shaped like a SonarQube issues response.
- Report only issues whose primary location maps to changed files and changed lines.
- Treat file-level issues without line numbers as relevant only when the file itself changed, and label them as file-level findings.
- Do not modify source code unless the user explicitly asks to fix the findings.

## Workflow

1. Confirm the current directory is inside the target Git repository.
2. Use the base branch provided by the user. If none is provided, infer a likely base such as `origin/main`, `origin/master`, `main`, or `master`; ask only when the base remains ambiguous.
3. Ensure the token is already stored in the persistent User or Machine environment as `SONAR_TOKEN` with `[System.Environment]::SetEnvironmentVariable`. If it is missing, stop and tell the user to set it outside chat, shell history, and logged sessions before continuing. Never ask the user to paste the token.
4. Download SonarQube issues with the bundled helper for the current platform, or use an existing report file if the user already provided one. Pass the SonarQube issues API URL explicitly:

   ```powershell
   .\scripts\download-sonar-issues.ps1 -SonarUrl "https://sonarqube.example.com/api/issues/search?componentKeys=my-project&inNewCodePeriod=true&issueStatuses=CONFIRMED,OPEN&ps=500&p=1&additionalFields=_all"
   ```

   ```bash
   ./scripts/download-sonar-issues.sh --url "https://sonarqube.example.com/api/issues/search?componentKeys=my-project&inNewCodePeriod=true&issueStatuses=CONFIRMED,OPEN&ps=500&p=1&additionalFields=_all"
   ```

   The helper writes to `.sonarqube-diff-review/<session-id>/sonarqube-issues.json` and prints the session id.
5. If the environment blocks network access, request the required approval and rerun the same helper. Never ask the user to paste the token into chat.
6. Inspect the report shape before diff matching:

   ```bash
   python scripts/inspect-sonar-report.py .sonarqube-diff-review/<session-id>/sonarqube-issues.json
   ```

   Use the actual report path from the helper output.
7. Generate committed changed-file and changed-line context only:

   ```bash
   git diff --name-only --find-renames <base>...HEAD
   git diff --unified=0 --find-renames <base>...HEAD
   ```

   Do not use `git diff` without commit refs, `git stash show`, or stashed patches for review/fix scope. If the worktree has uncommitted changes, mention that they were ignored.
8. Read [references/sonarqube-diff-triage.md](references/sonarqube-diff-triage.md) before mapping issues to diff hunks or writing the final findings.
9. Produce findings first, ordered by severity and confidence. Include file, line, rule, message, why it applies to the changed code, and the recommended fix.
10. Include a short note for ignored issues, such as counts outside the diff or report pagination limits, without dumping the full SonarQube JSON.

## Helper Inputs

The helpers support:

- Persistent `SONAR_TOKEN`: SonarQube token stored with `[System.Environment]::SetEnvironmentVariable` in the User or Machine environment. Process environment variables and token parameters are intentionally ignored.
- `-SonarUrl` / `--url`: Full SonarQube issues API URL from the user. Required.
- Output filename: defaults to `sonarqube-issues.json` inside `.sonarqube-diff-review/<session-id>/`.
- Session id: generated automatically; pass `-SessionId` / `--session-id` only when a stable folder name is needed.
- Authentication mode: `bearer` by default; use `basic` only when the server expects basic token authentication.

PowerShell parameters:

```powershell
.\scripts\download-sonar-issues.ps1 -SonarUrl "https://sonarqube.example.com/api/issues/search?componentKeys=my-project&ps=500&p=1" -OutputFile sonarqube-issues.json -AuthMode bearer
```

Bash arguments:

```bash
./scripts/download-sonar-issues.sh --url "https://sonarqube.example.com/api/issues/search?componentKeys=my-project&ps=500&p=1" --output sonarqube-issues.json --auth-mode bearer
```
