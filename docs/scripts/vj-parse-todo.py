#!/usr/bin/env python3
"""Read docs/1_youtube_links_to_download.md → tab-separated: group, url, sections."""
from __future__ import annotations

import re
import sys
from pathlib import Path

URL_RE = re.compile(
    r"https?://(?:www\.)?(?:"
    r"youtube\.com/(?:watch\?v=|live/|shorts/)|youtu\.be/)"
    r"([A-Za-z0-9_-]{11})[^\s]*"
)


def extract_url(line: str) -> str | None:
    m = URL_RE.search(line)
    if not m:
        return None
    return m.group(0).rstrip(".,)")


def is_commented_out_link(line: str) -> bool:
    s = line.strip()
    if not s.startswith("#"):
        return False
    return URL_RE.search(s) is not None


def is_section_heading(line: str) -> bool:
    s = line.strip()
    if not s.startswith("#"):
        return False
    if is_commented_out_link(line):
        return False
    rest = s[1:].strip()
    return URL_RE.search(rest) is None and rest != ""


def sections_from_notes(notes: list[str]) -> str:
    text = " ".join(notes).lower()
    if not text.strip():
        return ""
    if "1:00:00" in text or "1:00:10" in text:
        return "*1:00:00-1:00:10"
    if "start from 20" in text or "from 20 sec" in text:
        return "*0:20-0:30"
    if "10 second" in text or "10 sec" in text:
        if "20" in text:
            return "*0:20-0:30"
        return "*0:00-0:10"
    return ""


def parse_todo(path: Path) -> list[tuple[str, str, str]]:
    group = "Misc"
    notes: list[str] = []
    items: list[tuple[str, str, str]] = []

    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip("\n")
        stripped = line.strip()
        if not stripped:
            continue
        if is_section_heading(line):
            group = stripped[1:].strip()
            notes = []
            continue
        if is_commented_out_link(line):
            continue
        url = extract_url(line)
        if url:
            sec = sections_from_notes(notes)
            items.append((group, url, sec))
            notes = []
            continue
        if not stripped.startswith("#") and not URL_RE.search(stripped):
            notes.append(stripped)

    return items


def main() -> None:
    path = Path(sys.argv[1])
    for group, url, sections in parse_todo(path):
        print(f"{group}\t{url}\t{sections}")


if __name__ == "__main__":
    main()
