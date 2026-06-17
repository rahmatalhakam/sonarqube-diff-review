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
|-- .gitignore
|-- .codex-plugin/
|   `-- plugin.json
|-- .claude-plugin/
|   `-- marketplace.json
|-- agents/
|-- references/
`-- scripts/
```

The root `SKILL.md` intentionally uses only the common `name` and `description` frontmatter fields so the same repository can be installed by multiple AI tools.

The `skills` CLI discovers a root-level `SKILL.md`, so this repository can be installed directly with `npx skills add` without moving files into a nested `skills/` directory.

The Codex plugin wrapper relies on default root skill discovery instead of setting a custom `skills` path. The local Codex plugin validator rejects `skills: "./"`; omitting the field preserves the root skill layout and validates cleanly.

Format references:

- Agent Skills specification: https://agentskills.io/specification
- Gemini CLI Agent Skills: https://geminicli.com/docs/cli/skills/
- Claude Code skills: https://code.claude.com/docs/en/skills

## Contents

- `SKILL.md`: Skill trigger metadata and main workflow.
- `AGENTS.md`: Root instructions for Codex and other Agent Skills-compatible coding agents.
- `GEMINI.md`: Root context file for Gemini CLI.
- `.gitignore`: Local ignore rules for generated review artifacts and secrets.
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
- Node.js 18 or newer when installing with `npx skills`.
- Git, available on `PATH`.
- PowerShell 5+ or `pwsh` so helpers can read the persistent `SONAR_TOKEN` with `[System.Environment]`.
- curl for Bash usage. The PowerShell helper uses built-in web requests.
- Bash for Linux/macOS/Git Bash usage.
- Network access to the SonarQube server when downloading reports.

## Install

### Recommended: npx skills

Install from GitHub with the Agent Skills CLI:

```bash
npx skills add rahmatalhakam/sonarqube-diff-review
```

Install globally so supported agents can use it across projects:

```bash
npx skills add rahmatalhakam/sonarqube-diff-review --global
```

Install only for Codex:

```bash
npx skills add rahmatalhakam/sonarqube-diff-review --agent codex --global
```

List the skills discovered in this repository before installing:

```bash
npx skills add rahmatalhakam/sonarqube-diff-review --list
```

For non-interactive setup:

```bash
npx skills add rahmatalhakam/sonarqube-diff-review --agent codex --global --yes
```

Restart your agent after installing so the new skill is discovered.

### Manual Agent Skills Install

Use this fallback when you cannot use Node.js or `npx`:

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

Codex can use the recommended `npx skills` install above. Pass `--agent codex` when you want to target only Codex.

Manual clone into a Codex skills directory also works.

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

If installed with `npx skills`:

```bash
npx skills update sonarqube-diff-review --global
```

For project-scoped installs, omit `--global`.

If installed by manual git clone:

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

Store the SonarQube token before the review in persistent User or Machine environment storage as `SONAR_TOKEN` with `[System.Environment]::SetEnvironmentVariable`. Do this outside Codex chat, shell history, shell transcripts, and shared logs. The helpers intentionally reject token command arguments, prompts, `$env:SONAR_TOKEN`, and process `SONAR_TOKEN`.

Pass the SonarQube issues API URL as an explicit helper input. The helpers intentionally ignore `$env:SONAR_URL` and process `SONAR_URL`.

PowerShell:

```powershell
.\scripts\download-sonar-issues.ps1 -SonarUrl "https://sonarqube.example.com/api/issues/search?componentKeys=my-project&inNewCodePeriod=true&issueStatuses=CONFIRMED,OPEN&ps=500&p=1&additionalFields=_all"
```

Bash:

```bash
./scripts/download-sonar-issues.sh --url "https://sonarqube.example.com/api/issues/search?componentKeys=my-project&inNewCodePeriod=true&issueStatuses=CONFIRMED,OPEN&ps=500&p=1&additionalFields=_all"
```

Reports are saved under `.sonarqube-diff-review/<session-id>/sonarqube-issues.json`. The session id is generated automatically and printed by the helper. Use `-SessionId` or `--session-id` when a stable artifact folder name is needed.

Inspect an existing report:

```bash
python scripts/inspect-sonar-report.py .sonarqube-diff-review/<session-id>/sonarqube-issues.json
```

Then compare the report to the committed target branch diff:

```bash
git diff --name-only --find-renames <base>...HEAD
git diff --unified=0 --find-renames <base>...HEAD
```

Do not use unstaged, uncommitted, or stashed patches for review/fix scope.

## Safety Notes

- Read tokens only from persistent User or Machine `SONAR_TOKEN` set with `[System.Environment]::SetEnvironmentVariable`.
- Do not pass tokens through chat, prompts, command arguments, `$env:SONAR_TOKEN`, process `SONAR_TOKEN`, logs, or commits.
- Pass the SonarQube issue API URL with `-SonarUrl` or `--url`; do not use `$env:SONAR_URL` or process `SONAR_URL`.
- Keep generated reports and temp files inside `.sonarqube-diff-review/<session-id>/`.
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
python scripts/inspect-sonar-report.py .sonarqube-diff-review/<session-id>/sonarqube-issues.json
```
