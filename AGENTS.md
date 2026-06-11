# SonarQube Diff Review

Use the `sonarqube-diff-review` skill in this repository.

Rules:

- Download SonarQube issues using the helper scripts.
- Read the current Git diff.
- Fix only issues that overlap changed files and changed lines.
- Do not fix unrelated code outside the Git diff.
- Never expose SonarQube tokens in chat, logs, commits, or command output.
