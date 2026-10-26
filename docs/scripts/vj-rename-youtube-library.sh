#!/bin/bash
# One-time / maintenance: rename existing YouTube VJ MP4s to friendly names.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=vj-filename.sh
source "${SCRIPT_DIR}/vj-filename.sh"

# shellcheck source=vj-paths.sh
source "${SCRIPT_DIR}/vj-paths.sh"
BASE="${VJ_YOUTUBE}"
DONE="${SCRIPT_DIR}/../../docs/2_youtube_links_done.md"

renamed=0
skipped=0

while IFS= read -r -d '' f; do
  base=$(basename "$f")
  if vj_is_friendly_basename "$base"; then
    skipped=$((skipped + 1))
    continue
  fi
  id=$(vj_extract_youtube_id "$f" || true)
  if [[ -z "$id" ]]; then
    echo "SKIP (no id): $f"
    skipped=$((skipped + 1))
    continue
  fi
  title=$(vj_title_from_legacy_basename "$base")
  newpath=$(vj_finalize_youtube_file "$f" "$id" "$title")
  echo "RENAMED -> $(basename "$newpath")"
  renamed=$((renamed + 1))
done < <(find "$BASE" -type f -name '*.mp4' -print0)

if [[ -f "$DONE" ]]; then
  while IFS= read -r -d '' f; do
    old="$f"
    base=$(basename "$f")
    id=$(vj_extract_youtube_id "$f" || true)
    [[ -n "$id" ]] || continue
    title=$(vj_title_from_legacy_basename "$base")
    newbase=$(vj_youtube_basename "$title" "$id")
    newpath="$(dirname "$f")/${newbase}"
    if [[ "$old" != "$newpath" ]]; then
      perl -i -pe "s#\Q${old}\E#${newpath}#g" "$DONE" 2>/dev/null || true
    fi
  done < <(find "$BASE" -type f -name '*_1280x720_vj.mp4' -print0)
fi

echo "Done. Renamed: ${renamed}, skipped: ${skipped}."
