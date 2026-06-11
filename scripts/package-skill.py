#!/usr/bin/env python3
"""Create downloadable Agent Skill archives for GitHub releases."""

from __future__ import annotations

import argparse
import shutil
import zipfile
from pathlib import Path
from typing import Iterable


SKILL_NAME = "sonarqube-diff-review"
INCLUDE_PATHS = (
    ".claude-plugin",
    ".codex-plugin",
    ".gitattributes",
    "AGENTS.md",
    "GEMINI.md",
    "SKILL.md",
    "README.md",
    "agents",
    "references",
    "scripts",
)


def iter_package_files(root: Path) -> Iterable[Path]:
    for item in INCLUDE_PATHS:
        path = root / item
        if not path.exists():
            raise FileNotFoundError(f"Required package path is missing: {item}")

        if path.is_file():
            yield path
            continue

        for child in sorted(path.rglob("*")):
            if child.is_file() and "__pycache__" not in child.parts:
                yield child


def create_archive(root: Path, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for file_path in iter_package_files(root):
            archive.write(file_path, file_path.relative_to(root).as_posix())


def main() -> int:
    parser = argparse.ArgumentParser(description="Package the SonarQube Diff Review Agent Skill.")
    parser.add_argument("--output-dir", default="dist", help="Directory for generated release artifacts.")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    output_dir = root / args.output_dir

    zip_path = output_dir / f"{SKILL_NAME}.zip"
    skill_path = output_dir / f"{SKILL_NAME}.skill"

    create_archive(root, zip_path)
    shutil.copyfile(zip_path, skill_path)

    print(f"Created {zip_path.relative_to(root)}")
    print(f"Created {skill_path.relative_to(root)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
