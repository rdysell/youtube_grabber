#!/bin/bash
# Batch-download VJ clips per docs/instructions/vj_download_instructions.md
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=vj-job-common.sh
source "${SCRIPT_DIR}/vj-job-common.sh"

BASE="/Users/dysell/Library/Mobile Documents/com~apple~CloudDocs/VJ-Movies/YouTube"
LOG="${VJ_CACHE}/vj-batch.log"
REPO=$(cd "${SCRIPT_DIR}/../.." && pwd)
JOB=youtube-vj
TODO="${REPO}/docs/1_youtube_links_to_download.md"
DONE="${REPO}/docs/2_youtube_links_done.md"

mkdir -p "${HOME}/.cache/yt-dlp"

log() { vj_log "$LOG" "$@"; }

short_title() {
  yt-dlp --print "%(title)s" --no-download "$1" 2>/dev/null | head -c 120
}

video_id() {
  yt-dlp --print "%(id)s" --no-download "$1" 2>/dev/null
}

is_valid_vj_output() {
  local f="$1" w h vcodec audio_n
  [[ -f "$f" ]] || return 1
  w=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$f" 2>/dev/null) || return 1
  h=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$f" 2>/dev/null) || return 1
  vcodec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$f" 2>/dev/null) || return 1
  audio_n=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$f" 2>/dev/null | wc -l | tr -d ' ')
  [[ "$w" == "1280" && "$h" == "720" && "$vcodec" == "h264" && "$audio_n" == "0" ]]
}

file_meta() {
  local f="$1"
  local dur size
  dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$f" 2>/dev/null || echo "?")
  size=$(stat -f%z "$f" 2>/dev/null || echo "0")
  local size_h
  if command -v numfmt >/dev/null 2>&1; then
    size_h=$(numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || echo "${size} bytes")
  else
    size_h="${size} bytes"
  fi
  printf 'duration=%s size=%s' "$dur" "$size_h"
}

append_done() {
  local group="$1" url="$2" title="$3" path="$4" meta="$5" id="$6"
  if grep -q "\[${id}\]" "$DONE" 2>/dev/null; then
    return 0
  fi
  if ! grep -q "^# ${group}$" "$DONE" 2>/dev/null; then
    printf '\n# %s\n\n' "$group" >> "$DONE"
  fi
  {
    echo "- **${title}**"
    echo "  - URL: ${url}"
    echo "  - Path: \`${path}\`"
    echo "  - ${meta}"
    echo
  } >> "$DONE"
}

remove_from_todo() {
  local id="$1"
  local tmp
  tmp=$(mktemp)
  grep -v "$id" "$TODO" > "$tmp" || true
  mv "$tmp" "$TODO"
}

download_one_return() {
  local rc="${1:-0}"
  vj_maybe_stop_after_current "$JOB" "$LOG" "YouTube VJ batch"
  return "$rc"
}

download_one() {
  local group="$1" url="$2" sections="${3:-}"
  local id outfile title meta

  vj_maybe_stop_after_current "$JOB" "$LOG" "YouTube VJ batch"

  id=$(video_id "$url")
  if [[ -z "$id" ]]; then
    log "SKIP (no id): $url"
    return 1
  fi

  outfile=$(find "$BASE/$group" -name "*${id}*.mp4" -type f 2>/dev/null | head -1)
  if [[ -n "$outfile" ]] && is_valid_vj_output "$outfile"; then
    log "SKIP existing [$group] id=$id"
    title=$(short_title "$url")
    meta=$(file_meta "$outfile")
    append_done "$group" "$url" "$title" "$outfile" "$meta" "$id"
    remove_from_todo "$id"
    vj_bump_done "$JOB"
    download_one_return 0
  fi
  if [[ -n "$outfile" ]]; then
    log "RE-ENCODE incomplete VJ file [$group] id=$id"
    "${HOME}/.config/yt-dlp/vj-720.sh" "$outfile" || {
      log "FAIL re-encode [$group] $url"
      download_one_return 1
    }
    if is_valid_vj_output "$outfile"; then
      title=$(short_title "$url")
      meta=$(file_meta "$outfile")
      append_done "$group" "$url" "$title" "$outfile" "$meta" "$id"
      remove_from_todo "$id"
      log "OK [$group] $outfile ($meta)"
      vj_bump_done "$JOB"
      download_one_return 0
    fi
    log "FAIL still invalid after re-encode [$group] $url"
    download_one_return 1
  fi

  mkdir -p "$BASE/$group"

  vj_state_set "$JOB" CURRENT "[$group] $url"
  vj_state_set "$JOB" PHASE "downloading"
  log "START [$group] $url ${sections:+(sections $sections)}"
  if [[ -n "$sections" ]]; then
    if ! yt-dlp --download-sections "$sections" --force-keyframes-at-cuts \
      -P "$BASE/$group" "$url" >>"$LOG" 2>&1; then
      log "FAIL [$group] $url"
      download_one_return 1
    fi
  elif ! yt-dlp -P "$BASE/$group" "$url" >>"$LOG" 2>&1; then
    log "FAIL [$group] $url"
    download_one_return 1
  fi

  outfile=$(find "$BASE/$group" -name "*${id}*.mp4" -type f 2>/dev/null | head -1)
  if [[ -z "$outfile" ]]; then
    outfile=$(ls -t "$BASE/$group"/*.mp4 2>/dev/null | head -1)
  fi
  if [[ -z "$outfile" || ! -f "$outfile" ]]; then
    log "FAIL no output file [$group] $url"
    download_one_return 1
  fi

  title=$(short_title "$url")
  meta=$(file_meta "$outfile")
  append_done "$group" "$url" "$title" "$outfile" "$meta" "$id"
  remove_from_todo "$id"
  log "OK [$group] $outfile ($meta)"
  vj_bump_done "$JOB"
  download_one_return 0
}

main() {
  vj_job_acquire_pid "$JOB"
  local total
  total=$(grep -cE '^\s*download_one ' "${SCRIPT_DIR}/vj-download-all.sh" || echo 0)
  vj_state_set "$JOB" TOTAL "$total"
  vj_state_set "$JOB" DONE "0"
  vj_state_set "$JOB" PHASE "starting"
  vj_state_set "$JOB" CURRENT ""
  vj_state_set "$JOB" STOP_AFTER 0

  : >"$LOG"
  if [[ "${VJ_BACKGROUND:-}" != "1" ]]; then
    vj_print_job_banner "YouTube VJ batch" "make youtube-vj-status" "$LOG"
  fi
  log "VJ batch download started (${total} items)"

  # Short section clips first
  download_one "Woods, Nature and Weather" "https://www.youtube.com/live/bMmPHGJk2hE" "*0:20-0:30" || true
  download_one "Woods, Nature and Weather" "https://youtu.be/sGkh1W5cbH4" "*0:00-0:10" || true
  download_one "Woods, Nature and Weather" "https://youtu.be/AsD5u6k6dKI" "*0:00-0:10" || true
  download_one "Fireplace" "https://youtu.be/FU3ow3wS3PE" "*0:20-0:30" || true
  download_one "Fireplace" "https://youtu.be/p-zQ5YD7wDc" "*1:00:00-1:00:10" || true

  # Shorter full-length sources
  download_one "Animals" "https://youtu.be/ak_Gk83ewLY" || true
  download_one "Space,Universe and stars" "https://youtu.be/7kdJbeM6Ql4" || true
  download_one "Arty" "https://youtu.be/yx0HzBiaVn4" || true
  download_one "Abstract fluids" "https://youtu.be/y8ONlczgiXA" || true
  download_one "Abstract tunnels" "https://youtu.be/QxzU3FBy57k" || true

  # Remaining full-length (long encodes)
  download_one "Aurora" "https://youtu.be/miqbNFmbN2Q" || true
  download_one "Flying in the clouds" "https://youtu.be/w1E2zT_kEcw" || true
  download_one "Abstract fluids" "https://youtu.be/jgm58cbu0kw" || true
  download_one "Abstract fluids" "https://youtu.be/X5U86C4aXEc" || true
  download_one "Abstract fluids" "https://youtu.be/wjQq0nSGS28" || true
  download_one "Abstract fluids" "https://youtu.be/hOgVAYpHPCc" || true
  download_one "Abstract fluids" "https://youtu.be/-KS0QrFHAOU" || true
  download_one "Abstract fluids" "https://youtu.be/fOcRpAFfuHA" || true
  download_one "Abstract tunnels" "https://youtu.be/Ps-0f0K6izM" || true
  download_one "Woods, Nature and Weather" "https://youtu.be/VKSEG8Xr-RQ" || true
  download_one "Woods, Nature and Weather" "https://youtu.be/0fjo9ZwpepA" || true
  download_one "Woods, Nature and Weather" "https://youtu.be/TwXilp2mUtE" || true
  download_one "Space,Universe and stars" "https://youtu.be/ztVV54sPOns" || true

  vj_state_set "$JOB" PHASE "finished"
  vj_state_set "$JOB" CURRENT ""
  log "VJ batch download finished"
  vj_print_summary "$JOB" "$LOG" "YouTube VJ batch"
}

main "$@"
