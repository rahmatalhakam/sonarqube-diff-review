# Gemini Instructions

This repository provides the SonarQube Diff Review skill.

When asked to review SonarQube issues:

1. Read `SKILL.md`.
2. Use the scripts in `scripts/`.
3. Read `references/sonarqube-diff-triage.md`.
4. Use only the committed `<base>...HEAD` diff; ignore stashed and uncommitted changes.
5. Only report or fix issues that overlap changed files and changed lines.
6. Never accept tokens from prompts, command arguments, `$env:SONAR_TOKEN`, or process `SONAR_TOKEN`.
7. Save generated artifacts only under `.sonarqube-diff-review/<session-id>/`.
