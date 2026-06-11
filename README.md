# SonarQube Diff Review Agent Skill

Downloadable Agent Skill for Codex, Gemini CLI, and Claude Code. It downloads, inspects, and triages SonarQube issues against a Git diff, then reports only findings whose primary SonarQube location intersects changed files and changed lines.

Repository:

```text
https://github.com/rahmatalhakam/sonarqube-diff-review
```

## Compatibility

This repository uses the shared Agent Skills layout:

```text
sonarqube-diff-review/
|-- SKILL.md
|-- AGENTS.md
|-- GEMINI.md
|-- .codex-plugin/
|   `-- plugin.json
|-- .claude-plugin/
|   `-- marketplace.json
|-- agents/
|-- references/
`-- scripts/
```

The root `SKILL.md` intentionally uses only the common `name` and `description` frontmatter fields so the same repository can be installed by multiple AI tools.

The Codex plugin wrapper relies on default root skill discovery instead of setting a custom `skills` path. The local Codex plugin validator rejects `skills: "./"`; omitting the field preserves the root skill layout and validates cleanly.

Format references:

- Agent Skills specification: https://agentskills.io/specification
- Gemini CLI Agent Skills: https://geminicli.com/docs/cli/skills/
- Claude Code skills: https://code.claude.com/docs/en/skills

## Contents

- `SKILL.md`: Skill trigger metadata and main workflow.
- `AGENTS.md`: Root instructions for Codex and other Agent Skills-compatible coding agents.
- `GEMINI.md`: Root context file for Gemini CLI.
- `.codex-plugin/plugin.json`: Codex plugin wrapper for marketplace-style distribution.
- `.claude-plugin/marketplace.json`: Claude Code marketplace metadata.
- `agents/openai.yaml`: UI metadata for Codex skill lists.
- `references/sonarqube-diff-triage.md`: Detailed rules for mapping SonarQube issue locations to Git diff hunks.
- `scripts/download-sonar-issues.ps1`: Windows PowerShell helper for downloading issue reports.
- `scripts/download-sonar-issues.sh`: Bash helper for downloading issue reports.
- `scripts/inspect-sonar-report.py`: Report-shape validator and summary tool.
- `scripts/package-skill.py`: Creates downloadable `.zip` and `.skill` release artifacts.

## System Requirements

- Python 3.8 or newer.
- Git, available on `PATH`.
- curl, available as `curl.exe` on Windows or `curl` on Linux/macOS.
- PowerShell 5+ for Windows usage, or Bash for Linux/macOS/Git Bash usage.
- Network access to the SonarQube server when downloading reports.

## Install

### Manual Agent Skills Install

Use this path when you want the same checkout to work across Agent Skills-compatible tools:

```bash
mkdir -p ~/.agents/skills
git clone https://github.com/rahmatalhakam/sonarqube-diff-review.git ~/.agents/skills/sonarqube-diff-review
```

PowerShell:

```powershell
$skillsDir = Join-Path $HOME ".agents\skills"
New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
git clone https://github.com/rahmatalhakam/sonarqube-diff-review.git (Join-Path $skillsDir "sonarqube-diff-review")
```

For a project-scoped install, clone or copy this repository to:

```text
<project>/.agents/skills/sonarqube-diff-review/
```

### Codex

Codex can use the manual `.agents/skills` install above.

For plugin-style distribution, this repository includes `.codex-plugin/plugin.json`. After publishing the repository, users can add it as a plugin marketplace source:

```bash
codex plugin marketplace add rahmatalhakam/sonarqube-diff-review
```

Users can also clone it into a Codex skills directory directly.

PowerShell:

```powershell
$skillsDir = if ($env:CODEX_HOME) {
    Join-Path $env:CODEX_HOME "skills"
} else {
    Join-Path $HOME ".codex\skills"
}

New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
git clone https://github.com/rahmatalhakam/sonarqube-diff-review.git (Join-Path $skillsDir "sonarqube-diff-review")
```

Bash:

```bash
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
mkdir -p "$CODEX_HOME/skills"
git clone https://github.com/rahmatalhakam/sonarqube-diff-review.git "$CODEX_HOME/skills/sonarqube-diff-review"
```

Restart Codex after installing so the new skill is discovered.

### Gemini CLI

Install directly from the GitHub repository:

```bash
gemini skills install https://github.com/rahmatalhakam/sonarqube-diff-review
```

For local development, link this checkout instead:

```bash
gemini skills link .
```

Use `/skills list` inside Gemini CLI to confirm the skill is discovered.

### Claude Code

Install as a personal Claude Code skill:

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/rahmatalhakam/sonarqube-diff-review.git ~/.claude/skills/sonarqube-diff-review
```

PowerShell:

```powershell
$skillsDir = Join-Path $HOME ".claude\skills"
New-Item -ItemType Directory -Force -Path $skillsDir | Out-Null
git clone https://github.com/rahmatalhakam/sonarqube-diff-review.git (Join-Path $skillsDir "sonarqube-diff-review")
```

For a project-only install, clone or copy the repository to:

```text
.claude/skills/sonarqube-diff-review/
```

Run `/skills` in Claude Code to confirm the skill is available.

For marketplace-style distribution, this repository includes `.claude-plugin/marketplace.json`. Users can add it from Claude Code with:

```bash
/plugin marketplace add rahmatalhakam/sonarqube-diff-review
```

## Update Existing Install

Bash:

```bash
cd ~/.agents/skills/sonarqube-diff-review
git pull --ff-only
```

PowerShell:

```powershell
Set-Location "$HOME\.agents\skills\sonarqube-diff-review"
git pull --ff-only
```

If you installed into a product-specific directory, run `git pull --ff-only` from that checkout instead.

## Release Artifacts

Generate downloadable archives for GitHub Releases:

```bash
python scripts/package-skill.py
```

This creates:

```text
dist/sonarqube-diff-review.zip
dist/sonarqube-diff-review.skill
```

Upload those files to a GitHub Release. Use the repository URL for clients that support remote Git install, and use the generated archives for clients or users that prefer a downloaded package.

Before publishing, verify that `SKILL.md` starts with normal multiline YAML frontmatter:

```yaml
---
name: sonarqube-diff-review
description: Download, inspect, and triage SonarQube issue reports against Git diffs. Use when the agent needs to fetch SonarQube issues, compare them with changed files and changed lines, and report or fix only issues inside the current Git diff.
---
```

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
