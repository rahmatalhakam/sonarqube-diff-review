# SonarQube Diff Review

Use the `sonarqube-diff-review` skill in this repository.

Rules:

- Download SonarQube issues using the helper scripts.
- Read only the committed Git diff (`<base>...HEAD`), not stashed or uncommitted changes.
- Fix only issues that overlap changed files and changed lines.
- Do not fix unrelated code outside the Git diff.
- Use only persistent User/Machine `SONAR_TOKEN` from `[System.Environment]::SetEnvironmentVariable`; never use `$env:SONAR_TOKEN`, token prompts, or token arguments.
- Require the SonarQube URL as explicit helper input; never use `$env:SONAR_URL`.
- Save generated artifacts only under `.sonarqube-diff-review/<session-id>/`.
- Never expose SonarQube tokens in chat, logs, commits, or command output.
