#!/bin/bash
# Refresh Path: lines in 2_youtube_links_done.md from files on disk (match YouTube id).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=vj-filename.sh
source "${SCRIPT_DIR}/vj-filename.sh"

DONE="${SCRIPT_DIR}/../../docs/2_youtube_links_done.md"
BASE="${HOME}/Library/Mobile Documents/com~apple~CloudDocs/VJ-Movies/YouTube"

python3 - "$DONE" "$BASE" <<'PY'
import re, sys
from pathlib import Path

done_path = Path(sys.argv[1])
base = Path(sys.argv[2])
text = done_path.read_text(encoding="utf-8")

def find_file(vid: str) -> str | None:
    for p in base.rglob("*.mp4"):
        if f"_{vid}_" in p.name or f"[{vid}]" in p.name:
            return str(p)
    return None

def repl_line(line: str) -> str:
    m = re.search(r"https://(?:www\.)?youtube\.com/(?:watch\?v=|live/)([a-zA-Z0-9_-]+)", line)
    if not m:
        m = re.search(r"youtu\.be/([a-zA-Z0-9_-]+)", line)
    if not m:
        return line
    vid = m.group(1)
    path = find_file(vid)
    if not path:
        return line
    if line.strip().startswith("- Path:"):
        return f"  - Path: `{path}`"
    return line

lines = []
for line in text.splitlines():
    if line.strip().startswith("- Path:"):
        # look back isn't needed; update using id from nearby URL in prior lines
        lines.append(line)
        continue
    lines.append(line)

out = []
i = 0
rows = text.splitlines()
while i < len(rows):
    line = rows[i]
    if line.strip().startswith("- Path:"):
        vid = None
        for j in range(i - 1, max(i - 6, -1), -1):
            m = re.search(r"youtu\.be/([a-zA-Z0-9_-]+)", rows[j])
            if m:
                vid = m.group(1)
                break
            m = re.search(r"youtube\.com/(?:live/|watch\?v=)([a-zA-Z0-9_-]+)", rows[j])
            if m:
                vid = m.group(1)
                break
        if vid:
            path = find_file(vid)
            if path:
                out.append(f"  - Path: `{path}`")
            else:
                out.append(line)
        else:
            out.append(line)
    else:
        out.append(line)
    i += 1

done_path.write_text("\n".join(out) + "\n", encoding="utf-8")
print(f"Updated paths in {done_path}")
PY
