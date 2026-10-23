# Shared naming for convert-vj-splits.
# Clip names use letters, numbers, "_" and "-" only.
# The part before ".mp4" is kept within 100 characters (same cap as convert-vj archive names).

VJ_SPLIT_SEGMENT_SEC=55
VJ_SPLIT_NAME_MAX=100

vj_split_sanitize() {
  local s="$1"
  s=$(printf '%s' "$s" | LC_ALL=C tr '[:space:]' '_' | LC_ALL=C tr '.' '_' | LC_ALL=C tr -cd '[:alnum:]_-')
  while [[ "$s" == *__* ]]; do
    s=${s//__/_}
  done
  while [[ "$s" == _* ]]; do
    s=${s#_}
  done
  while [[ "$s" == *_ ]]; do
    s=${s%_}
  done
  if [[ -z "$s" ]]; then
    s="clip"
  fi
  printf '%s\n' "$s"
}

# Seconds -> 00-00-00 (hyphens, so the name is safe on every filesystem).
vj_split_fmt_hms() {
  awk -v x="$1" 'BEGIN {
    if (x == "" || (x + 0) < 0) x = 0
    n = int(x + 0.5)
    printf "%02d-%02d-%02d", int(n/3600), int(n/60)%60, n%60
  }'
}

vj_split_fmt_clock() {
  awk -v x="$1" 'BEGIN {
    if (x == "" || (x + 0) < 0) x = 0
    n = int(x + 0.5)
    printf "%02d:%02d:%02d", int(n/3600), int(n/60)%60, n%60
  }'
}

vj_split_is_number() {
  [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

# Shorten a stem so stem + reserve stays within VJ_SPLIT_NAME_MAX.
# Prefer cutting on "_" so the name does not end mid-word.
vj_split_shorten() {
  local stem="$1" reserve="$2" budget cut trimmed
  budget=$((VJ_SPLIT_NAME_MAX - reserve))
  if [[ "$budget" -lt 12 ]]; then
    budget=12
  fi
  if [[ ${#stem} -le $budget ]]; then
    printf '%s\n' "$stem"
    return 0
  fi
  cut="${stem:0:$budget}"
  if [[ "$cut" == *_* ]]; then
    trimmed="${cut%_*}"
    if [[ ${#trimmed} -ge 12 ]]; then
      cut="$trimmed"
    fi
  fi
  while [[ "$cut" == *_ ]]; do
    cut="${cut%_}"
  done
  if [[ -z "$cut" ]]; then
    cut="clip"
  fi
  printf '%s\n' "$cut"
}

vj_split_estimate_count() {
  awk -v d="$1" -v s="${2:-$VJ_SPLIT_SEGMENT_SEC}" 'BEGIN {
    if ((d + 0) <= 0) { print 0; exit }
    n = int(d / s)
    if (d > (n * s)) n++
    if (n < 1) n = 1
    print n
  }'
}

# Stem used for the clips folder and for every clip file.
vj_split_stem_for() {
  local video="$1" duration="$2" base stem end_stamp reserve
  base=$(basename "$video")
  stem=${base%.*}
  stem=$(vj_split_sanitize "$stem")
  end_stamp=$(vj_split_fmt_hms "$duration")
  reserve=$((1 + ${#end_stamp} + 4 + ${#end_stamp}))
  vj_split_shorten "$stem" "$reserve"
}

# Folder next to the source. Reuse it for the same file; otherwise stem_clips_2, ...
vj_split_pick_dir() {
  local parent="$1" stem="$2" video="$3"
  local base="${parent}/${stem}_clips"
  local candidate="$base" n=2 marker existing
  while [[ -d "$candidate" ]]; do
    marker="${candidate}/.source-path"
    if [[ ! -f "$marker" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
    existing=$(<"$marker")
    if [[ "$existing" == "$video" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
    candidate="${base}_${n}"
    n=$((n + 1))
    if [[ "$n" -gt 100 ]]; then
      echo "Too many clip folders for ${stem}" >&2
      return 1
    fi
  done
  printf '%s\n' "$candidate"
}

vj_split_duration() {
  local d
  d=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$1" 2>/dev/null || true)
  printf '%s\n' "${d%%$'\n'*}"
}

vj_split_has_video() {
  local c
  c=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_type -of csv=p=0 "$1" 2>/dev/null || true)
  [[ "${c%%$'\n'*}" == "video" ]]
}

# macOS iCloud placeholder (file is not on disk yet).
vj_split_is_dataless() {
  local flags
  flags=$(ls -ldO "$1" 2>/dev/null | awk '{print $5}')
  [[ "$flags" == *dataless* ]]
}
