#!/usr/bin/env python3
"""Merge the dotfiles status-line settings into an existing Codex config."""

from __future__ import annotations

import sys
from pathlib import Path


STATUS_LINE = (
    'status_line = ["model-with-reasoning", "current-dir", "git-branch", '
    '"context-remaining", "five-hour-limit", "weekly-limit"]'
)
STATUS_COLORS = "status_line_use_colors = true"
STATUS_THEME = 'theme = "dotfiles"'
MANAGED_KEYS = ("status_line", "status_line_use_colors", "theme")


def remove_managed_keys(lines: list[str], start: int, end: int) -> list[str]:
    result: list[str] = []
    index = start
    while index < end:
        stripped = lines[index].lstrip()
        key = next((key for key in MANAGED_KEYS if stripped.startswith(f"{key} =")), None)
        if key is None:
            result.append(lines[index])
            index += 1
            continue

        balance = lines[index].count("[") - lines[index].count("]")
        index += 1
        while balance > 0 and index < end:
            balance += lines[index].count("[") - lines[index].count("]")
            index += 1
    return result


def update_config(path: Path) -> None:
    text = path.read_text() if path.exists() else ""
    lines = text.splitlines(keepends=True)
    section_start = next(
        (index for index, line in enumerate(lines) if line.strip() == "[tui]"), None
    )

    managed = [f"{STATUS_LINE}\n", f"{STATUS_COLORS}\n", f"{STATUS_THEME}\n"]
    if section_start is None:
        if text and not text.endswith("\n"):
            lines.append("\n")
        if lines and lines[-1].strip():
            lines.append("\n")
        lines.extend(["[tui]\n", *managed])
    else:
        section_end = next(
            (
                index
                for index in range(section_start + 1, len(lines))
                if lines[index].lstrip().startswith("[")
            ),
            len(lines),
        )
        body = remove_managed_keys(lines, section_start + 1, section_end)
        lines = lines[: section_start + 1] + managed + body + lines[section_end:]

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(lines))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(f"Usage: {sys.argv[0]} <config.toml>")
    update_config(Path(sys.argv[1]).expanduser())
