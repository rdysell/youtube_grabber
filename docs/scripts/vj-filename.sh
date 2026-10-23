# System-friendly VJ filenames: ASCII, underscores, YouTube id, resolution tag.
# Example: Cozy_Fireplace_4K_HDR_60fps_qeWLeTQAjzU_1280x720_vj.mp4
VJ_RES_TAG="1280x720"

vj_sanitize_title() {
  local s="$1" max="${2:-64}"
  s=$(python3 - "$s" "$max" <<'PY' 2>/dev/null || true
import re, sys
s = sys.argv[1]
max_len = int(sys.argv[2])
s = re.sub(r"[^\w\s-]", " ", s, flags=re.UNICODE)
s = re.sub(r"[\s.]+", "_", s.strip())
s = re.sub(r"_+", "_", s).strip("_")
if not s:
    s = "video"
print(s[:max_len].rstrip("_"))
PY
  )
  if [[ -z "$s" ]]; then
    s="video"
  fi
  printf '%s' "$s"
}

vj_youtube_basename() {
  local title="$1" id="$2"
  local safe
  title=$(printf '%s' "$title" | sed -E 's/[[:space:]]*\[[^]]*\][[:space:]]*$//')
  safe=$(vj_sanitize_title "$title" 64)
  safe=${safe%_"$id"}
  safe=${safe%"$id"}
  printf '%s_%s_%s_vj.mp4' "$safe" "$id" "$VJ_RES_TAG"
}

# From "… [VIDEO_ID].mp4" or "…_VIDEO_ID_1280x720_vj.mp4"
vj_extract_youtube_id() {
  local path="$1" base id
  base=$(basename "$path")
  base="${base%.mp4}"
  case "$base" in
    *"["*"]")
      id=${base##*[}
      id=${id%]*}
      printf '%s' "$id"
      return 0
      ;;
    *_1280x720_vj)
      id=${base%_${VJ_RES_TAG}_vj}
      # YouTube ids are 11 characters (may include _-).
      if [[ ${#id} -ge 11 ]]; then
        id=${id: -11}
      fi
      printf '%s' "$id"
      return 0
      ;;
  esac
  return 1
}

vj_title_from_legacy_basename() {
  local base="$1" id rest
  base=$(basename "$base" .mp4)
  base=$(printf '%s' "$base" | sed -E 's/[[:space:]]*\[[^]]*\][[:space:]]*$//')
  if [[ "$base" == *"_${VJ_RES_TAG}_vj" ]]; then
    id=$(vj_extract_youtube_id "$base.mp4" 2>/dev/null) || id=""
    if [[ -n "$id" ]]; then
      rest=${base%_${VJ_RES_TAG}_vj}
      vj_title_stem_before_id "$rest" "$id"
      return 0
    fi
    base=${base%_${VJ_RES_TAG}_vj}
    base=${base%_*}
  fi
  printf '%s' "$base"
}

# Strip mistaken extra id-like suffixes (botched renames); keeps title stem with underscores.
vj_title_stem_before_id() {
  local rest="$1" id="$2" tail
  rest=${rest%_"$id"}
  while [[ "$rest" =~ _([A-Za-z0-9_-]{10,11})$ ]]; do
    tail="${BASH_REMATCH[1]}"
    [[ "$tail" =~ [0-9] ]] || break
    rest=${rest%_"$tail"}
  done
  printf '%s' "$rest"
}

vj_is_friendly_basename() {
  local base="$1" id rest title_part expected
  [[ "$base" == *"_${VJ_RES_TAG}_vj.mp4" ]] || return 1
  id=$(vj_extract_youtube_id "$base") || return 1
  rest=${base%_${VJ_RES_TAG}_vj.mp4}
  [[ "$rest" == *_"$id" ]] || return 1
  title_part=$(vj_title_stem_before_id "$rest" "$id")
  expected=$(vj_youtube_basename "${title_part//_/ }" "$id")
  [[ "$base" == "$expected" ]]
}

# Rename encoded file to friendly name; prints final path on stdout.
vj_finalize_youtube_file() {
  local filepath="$1" id="$2" title="$3"
  local dir base new newpath
  [[ -f "$filepath" ]] || return 1
  dir=$(dirname "$filepath")
  base=$(basename "$filepath")
  if [[ -z "$id" ]]; then
    id=$(vj_extract_youtube_id "$filepath") || return 0
  fi
  if [[ -z "$title" ]]; then
    title=$(vj_title_from_legacy_basename "$base")
  fi
  if [[ "$title" == *"_"* ]]; then
    title=${title//_/ }
  fi
  new=$(vj_youtube_basename "$title" "$id")
  if [[ "$base" == "$new" ]]; then
    printf '%s\n' "$filepath"
    return 0
  fi
  newpath="$dir/$new"
  if [[ -e "$newpath" && "$newpath" != "$filepath" ]]; then
    rm -f "$newpath"
  fi
  mv -f "$filepath" "$newpath"
  printf '%s\n' "$newpath"
}
