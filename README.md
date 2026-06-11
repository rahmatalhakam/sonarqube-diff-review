# SonarQube Diff Review Skill

Codex skill for downloading, inspecting, and triaging SonarQube issues against a Git diff. It is designed to report only findings whose primary SonarQube location intersects changed files and changed lines.

## Contents

- `SKILL.md`: Skill trigger metadata and main workflow.
- `agents/openai.yaml`: UI metadata for Codex skill lists.
- `references/sonarqube-diff-triage.md`: Detailed rules for mapping SonarQube issue locations to Git diff hunks.
- `scripts/download-sonar-issues.ps1`: Windows PowerShell helper for downloading issue reports.
- `scripts/download-sonar-issues.sh`: Bash helper for downloading issue reports.
- `scripts/inspect-sonar-report.py`: Report-shape validator and summary tool.

## System Requirements

- Python 3.8 or newer.
- Git, available on `PATH`.
- curl, available as `curl.exe` on Windows or `curl` on Linux/macOS.
- PowerShell 5+ for Windows usage, or Bash for Linux/macOS/Git Bash usage.
- Network access to the SonarQube server when downloading reports.

## Usage

Set the SonarQube API URL and token in environment variables, then run the helper for your shell.

PowerShell:

```powershell
$env:SONAR_TOKEN="squ_xxxxxxxxxxxxxxxxx"
$env:SONAR_URL="https://sonarqube.example.com/api/issues/search?componentKeys=my-project&inNewCodePeriod=true&issueStatuses=CONFIRMED,OPEN&ps=500&p=1&additionalFields=_all"
.\scripts\download-sonar-issues.ps1
```

Bash:

```bash
export SONAR_TOKEN="squ_xxxxxxxxxxxxxxxxx"
export SONAR_URL="https://sonarqube.example.com/api/issues/search?componentKeys=my-project&inNewCodePeriod=true&issueStatuses=CONFIRMED,OPEN&ps=500&p=1&additionalFields=_all"
./scripts/download-sonar-issues.sh
```

Inspect an existing report:

```bash
python scripts/inspect-sonar-report.py sonar-issues.json
```

Then compare the report to a target branch diff:

```bash
git diff --name-only --find-renames <base>...HEAD
git diff --unified=0 --find-renames <base>...HEAD
```

## Safety Notes

- Prefer `SONAR_TOKEN` and `SONAR_URL` environment variables over inline tokens.
- Do not commit downloaded SonarQube reports, temporary files, logs, or environment files.
- Fetch all SonarQube pages before claiming a branch has no relevant findings.
- Treat secondary flow locations as supporting context unless explicitly doing deeper flow analysis.

## Validation

Validate the skill metadata with the Codex skill validator:

```bash
python <path-to-skill-creator>/scripts/quick_validate.py .
```

Validate a real report:

```bash
python scripts/inspect-sonar-report.py sonar-issues.json
```
