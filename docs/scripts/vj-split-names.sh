# Shared naming for convert-vj-splits.
# Clip files: Short_Title__0h-05-33_to_0h-06-25.mp4
# Folder: Short_Title_YouTubeId_clips

# Clip length in seconds. Default 55.
# `make convert-vj-splits-20s` exports VJ_SPLIT_SEGMENT_SEC=20 before these scripts run.
# Shared by the clips folder and every clip file. A YouTube id is added on the folder only.
VJ_SPLIT_FOLDER_TITLE_MAX=24

# Keep a passed-in length, otherwise 55. Whole seconds from 1 to 86400.
vj_split_apply_segment_sec() {
  local sec="${VJ_SPLIT_SEGMENT_SEC:-55}"
  if [[ ! "$sec" =~ ^[0-9]+$ ]]; then
    echo "Clip length must be a whole number of seconds. Example: make convert-vj-splits-20s" >&2
    return 1
  fi
  sec=$((10#$sec))
  if [[ "$sec" -lt 1 || "$sec" -gt 86400 ]]; then
    echo "Clip length must be from 1 to 86400 seconds (got ${sec})." >&2
    return 1
  fi
  VJ_SPLIT_SEGMENT_SEC=$sec
  export VJ_SPLIT_SEGMENT_SEC
}

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

# Seconds -> 0h-05-33. Hours are not zero-padded. Minutes and seconds stay two digits.
vj_split_fmt_hms() {
  awk -v x="$1" 'BEGIN {
    if (x == "" || (x + 0) < 0) x = 0
    n = int(x + 0.5)
    printf "%dh-%02d-%02d", int(n/3600), int(n/60)%60, n%60
  }'
}

# 00-05-33 -> 0h-05-33. Leaves a stamp alone when it already uses the h form.
vj_split_reformat_stamp() {
  local stamp="$1" h m s
  if [[ "$stamp" =~ ^([0-9]+)h-([0-9]{2})-([0-9]{2})$ ]]; then
    printf '%s\n' "$stamp"
    return 0
  fi
  if [[ "$stamp" =~ ^([0-9]{2})-([0-9]{2})-([0-9]{2})$ ]]; then
    h="${BASH_REMATCH[1]}"
    m="${BASH_REMATCH[2]}"
    s="${BASH_REMATCH[3]}"
    printf '%dh-%s-%s\n' "$((10#$h))" "$m" "$s"
    return 0
  fi
  printf '%s\n' "$stamp"
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

# Prefer cutting on "_" so the name does not end mid-word.
vj_split_shorten_to() {
  local stem="$1" budget="$2" cut trimmed
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

# YouTube id from a VJ filename, or empty.
vj_split_youtube_id() {
  local video="$1" base raw id title
  base=$(basename "$video")
  raw=${base%.*}
  id=""
  if [[ "$raw" == *"["*"]"* ]]; then
    id=${raw##*[}
    id=${id%]*}
    id=${id//[^A-Za-z0-9_-]/}
  fi
  title=$(vj_split_sanitize "$raw")
  if [[ -z "$id" && "$title" == *_1280x720_vj ]]; then
    title=${title%_1280x720_vj}
    if [[ ${#title} -ge 12 ]]; then
      id=${title:$((${#title} - 11))}
      if [[ "$title" != *"_"$id ]]; then
        id=""
      fi
    fi
  fi
  if [[ "$id" =~ ^[A-Za-z0-9_-]{11}$ ]]; then
    printf '%s\n' "$id"
  fi
}

# Short title shared by the folder and every clip. No YouTube id.
# Abstract_Liquid_..._jgm58cbu0kw_1280x720_vj.mp4 -> Abstract_Liquid
vj_split_clip_title() {
  local video="$1" id title
  id=$(vj_split_youtube_id "$video")
  title=$(vj_split_sanitize "$(basename "${video%.*}")")
  title=${title%_1280x720_vj}
  if [[ -n "$id" && "$title" == *"_"$id ]]; then
    title=${title%_"$id"}
  fi
  vj_split_shorten_to "$title" "$VJ_SPLIT_FOLDER_TITLE_MAX"
}

# Abstract_Liquid__0h-05-33_to_0h-06-25.mp4
vj_split_clip_name() {
  local title="$1" start="$2" end="$3"
  printf '%s__%s_to_%s.mp4\n' "$title" "$(vj_split_fmt_hms "$start")" "$(vj_split_fmt_hms "$end")"
}

# Short folder name: the clip title, plus the YouTube id when the file has one.
vj_split_folder_stem() {
  local video="$1" title id
  title=$(vj_split_clip_title "$video")
  id=$(vj_split_youtube_id "$video")
  if [[ -n "$id" ]]; then
    printf '%s_%s\n' "$title" "$id"
  else
    printf '%s\n' "$title"
  fi
}

# Sidecar in ~/.cache (not next to clips) so iCloud clip folders stay clean.
vj_split_source_marker() {
  local out_dir="$1" cache="${VJ_CACHE:-${HOME}/.cache/yt-dlp}" hash
  hash=$(printf '%s' "$out_dir" | LC_ALL=C shasum -a 256 | awk '{print $1}')
  printf '%s\n' "${cache}/split-source-${hash}.path"
}

vj_split_set_source_marker() {
  local out_dir="$1" video="$2" marker
  marker=$(vj_split_source_marker "$out_dir")
  mkdir -p "${marker%/*}" || return 1
  printf '%s\n' "$video" >"$marker"
}

vj_split_clear_source_marker() {
  local out_dir="$1" marker
  marker=$(vj_split_source_marker "$out_dir")
  rm -f "$marker"
}

# Cache marker, or a legacy .source-path left inside an older clips folder.
vj_split_marker_video() {
  local out_dir="$1" marker
  marker=$(vj_split_source_marker "$out_dir")
  if [[ -f "$marker" ]]; then
    printf '%s\n' "$(<"$marker")"
    return 0
  fi
  if [[ -f "$out_dir/.source-path" ]]; then
    printf '%s\n' "$(<"$out_dir/.source-path")"
    return 0
  fi
  return 1
}

# Directory under parent whose marker records this source video.
vj_split_find_source_dir() {
  local parent="$1" video="$2" d existing saved=0
  shopt -q nullglob && saved=1
  shopt -s nullglob
  for d in "$parent"/*/; do
    d="${d%/}"
    existing=$(vj_split_marker_video "$d" || true)
    if [[ -n "$existing" && "$existing" == "$video" ]]; then
      if [[ "$saved" -eq 0 ]]; then
        shopt -u nullglob
      fi
      printf '%s\n' "$d"
      return 0
    fi
  done
  if [[ "$saved" -eq 0 ]]; then
    shopt -u nullglob
  fi
  return 1
}

# Folder next to the source. A previous clips folder for this same file is renamed
# to the short name. A different file that shortens to the same name gets _2, _3, ...
vj_split_pick_dir() {
  local parent="$1" stem="$2" video="$3"
  local base="${parent}/${stem}_clips"
  local found="" candidate n=2 marked=""
  found=$(vj_split_find_source_dir "$parent" "$video" || true)
  if [[ -n "$found" ]]; then
    if [[ "$found" == "$base" ]]; then
      printf '%s\n' "$base"
      return 0
    fi
    if [[ ! -e "$base" ]] && mv "$found" "$base"; then
      vj_split_clear_source_marker "$found"
      rm -f "$base/.source-path"
      vj_split_set_source_marker "$base" "$video" || true
      printf '%s\n' "$base"
      return 0
    fi
    printf '%s\n' "$found"
    return 0
  fi
  candidate="$base"
  while [[ -d "$candidate" ]]; do
    marked=$(vj_split_marker_video "$candidate" || true)
    if [[ -z "$marked" || "$marked" == "$video" ]]; then
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
