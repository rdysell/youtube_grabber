#!/bin/bash
# Fail if the repo still mentions old VJ library paths (iCloud or VJ-Movies).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

PATTERNS=(
  'VJ-Movies'
  'CloudDocs/VJ'
  'com~apple~CloudDocs/VJ-Movies'
  'Mobile Documents/com~apple~CloudDocs/VJ'
)

hits=0
for pat in "${PATTERNS[@]}"; do
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "$line"
    hits=$((hits + 1))
  done < <(rg -n --glob '!.git' --glob '!yt_dlp/**' --glob '!test/**' --glob '!uv.lock' \
    --glob '!docs/scripts/vj-check-stale-paths.sh' \
    -e "$pat" . 2>/dev/null || true)
done

if [[ "$hits" -gt 0 ]]; then
  echo ""
  echo "Found ${hits} stale path reference(s). Use /Volumes/Elephant/VJ (see docs/scripts/vj-paths.sh)." >&2
  exit 1
fi

echo "OK: no stale VJ path strings (VJ-Movies / iCloud CloudDocs VJ) under ${ROOT}."
