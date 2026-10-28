#!/bin/bash
# Move flat VJ outputs in Converted_media_files into per-movie subfolders (one-time / maintenance).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=vj-paths.sh
source "${SCRIPT_DIR}/vj-paths.sh"

OUTBOX="${VJ_CONVERT_OUTBOX}"

collection_from_vj_basename() {
  local base="$1" stem
  stem="${base%.mp4}"
  stem=${stem%_1280x720_vj}
  if [[ "$stem" =~ ^(.+)_[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "$stem" =~ ^(.+)_[0-9]{4}$ ]]; then
    printf '%s\n' "$stem"
    return 0
  fi
  printf '%s\n' "$stem"
}

moved=0
skipped=0

while IFS= read -r -d '' f; do
  base=$(basename "$f")
  coll=$(collection_from_vj_basename "$base")
  [[ -n "$coll" ]] || continue
  dest_dir="${OUTBOX}/${coll}"
  dest="${dest_dir}/${base}"
  if [[ "$f" == "$dest" ]]; then
    skipped=$((skipped + 1))
    continue
  fi
  mkdir -p "$dest_dir"
  if [[ -e "$dest" ]]; then
    echo "SKIP (exists): $dest"
    skipped=$((skipped + 1))
    continue
  fi
  mv -f "$f" "$dest"
  echo "MOVED -> ${coll}/${base}"
  moved=$((moved + 1))
done < <(find "$OUTBOX" -maxdepth 1 -type f -name '*_1280x720_vj.mp4' -print0)

echo "Done. Moved: ${moved}, skipped: ${skipped}."
