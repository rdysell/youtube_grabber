#!/bin/bash
# Batch-download VJ clips per docs/instructions/vj_download_instructions.md
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=vj-job-common.sh
source "${SCRIPT_DIR}/vj-job-common.sh"
# shellcheck source=vj-filename.sh
source "${SCRIPT_DIR}/vj-filename.sh"
# shellcheck source=vj-paths.sh
source "${SCRIPT_DIR}/vj-paths.sh"

BASE="${VJ_YOUTUBE}"
LOG="${VJ_CACHE}/vj-batch.log"
REPO=$(cd "${SCRIPT_DIR}/../.." && pwd)
JOB=youtube-vj
TODO="${REPO}/docs/1_youtube_links_to_download.md"
DONE="${REPO}/docs/2_youtube_links_done.md"

mkdir -p "${HOME}/.cache/yt-dlp"

log() { vj_log "$LOG" "$@"; }

short_title() {
  yt-dlp --ignore-config --print "%(title)s" --no-download "$1" 2>/dev/null | head -c 120
}

video_id() {
  yt-dlp --ignore-config --print "%(id)s" --no-download "$1" 2>/dev/null
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
  if grep -q "_${id}_" "$DONE" 2>/dev/null || grep -q "\[${id}\]" "$DONE" 2>/dev/null; then
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

finalize_outfile() {
  local url="$1" path="$2" id title
  id=$(video_id "$url")
  title=$(short_title "$url")
  vj_finalize_youtube_file "$path" "$id" "$title"
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
    log "FAIL (no video id) [$group] $url"
    return 1
  fi

  outfile=$(find "$BASE/$group" -name "*${id}*.mp4" -type f 2>/dev/null | head -1)
  if [[ -n "$outfile" ]] && is_valid_vj_output "$outfile"; then
    log "SKIP existing [$group] id=$id"
    title=$(short_title "$url")
    outfile=$(finalize_outfile "$url" "$outfile")
    meta=$(file_meta "$outfile")
    append_done "$group" "$url" "$title" "$outfile" "$meta" "$id"
    remove_from_todo "$id"
    vj_bump_done "$JOB"
    download_one_return 0
  fi
  if [[ -n "$outfile" ]]; then
    log "RE-ENCODE incomplete VJ file [$group] id=$id"
    title=$(short_title "$url")
    "${HOME}/.config/yt-dlp/vj-720.sh" "$outfile" "$id" "$title" || {
      log "FAIL re-encode [$group] $url"
      download_one_return 1
    }
    outfile=$(finalize_outfile "$url" "$outfile")
    if is_valid_vj_output "$outfile"; then
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
  outfile=$(finalize_outfile "$url" "$outfile")
  meta=$(file_meta "$outfile")
  append_done "$group" "$url" "$title" "$outfile" "$meta" "$id"
  remove_from_todo "$id"
  log "OK [$group] $outfile ($meta)"
  vj_bump_done "$JOB"
  download_one_return 0
}

log_batch_audit() {
  local queue_file="$1" total="$2"
  local ok skip fail started never
  ok=$(grep -cE '\] OK \[' "$LOG" 2>/dev/null || true)
  skip=$(grep -cE '\] SKIP ' "$LOG" 2>/dev/null || true)
  fail=$(grep -cE '\] FAIL ' "$LOG" 2>/dev/null || true)
  started=$(grep -cE '\] START \[' "$LOG" 2>/dev/null || true)
  ok=${ok:-0}
  skip=${skip:-0}
  fail=${fail:-0}
  started=${started:-0}
  never=0
  log "Batch counts: OK=${ok} SKIP=${skip} FAIL=${fail} START=${started} (queue=${total})"

  while IFS=$'\t' read -r group url _sections; do
    [[ -n "$url" ]] || continue
    if grep -qF "$url" "$LOG" 2>/dev/null; then
      continue
    fi
    local audit_id
    audit_id=$(video_id "$url")
    if [[ -n "$audit_id" ]] && grep -qF "id=${audit_id}" "$LOG" 2>/dev/null; then
      continue
    fi
    never=$((never + 1))
    log "FAIL never started [$group] $url"
  done <"$queue_file"

  if [[ "$never" -gt 0 ]]; then
    log "FAIL audit: ${never} queue item(s) had no log line (batch bug or early exit)"
  fi
}

main() {
  vj_job_acquire_pid "$JOB"
  local total group url sections queue_file
  local -a queue_lines=()
  if [[ ! -f "$TODO" ]]; then
    echo "Missing queue file: $TODO" >&2
    exit 1
  fi
  queue_file=$(mktemp "${TMPDIR:-/tmp}/vj-youtube-queue.XXXXXX")
  python3 "${SCRIPT_DIR}/vj-parse-todo.py" "$TODO" >"$queue_file"
  mapfile -t queue_lines <"$queue_file"
  total=${#queue_lines[@]}
  vj_state_set "$JOB" TOTAL "$total"
  vj_state_set "$JOB" DONE "0"
  vj_state_set "$JOB" PHASE "starting"
  vj_state_set "$JOB" CURRENT ""
  vj_state_set "$JOB" STOP_AFTER 0

  : >"$LOG"
  if [[ "${VJ_BACKGROUND:-}" != "1" ]]; then
    vj_print_job_banner "YouTube VJ batch" "make youtube-vj-status" "$LOG"
  fi
  log "VJ batch download started (${total} items from ${TODO})"

  for line in "${queue_lines[@]}"; do
    [[ -n "$line" ]] || continue
    IFS=$'\t' read -r group url sections <<<"$line"
    [[ -n "$url" ]] || continue
    if [[ -n "$sections" ]]; then
      download_one "$group" "$url" "$sections" || true
    else
      download_one "$group" "$url" || true
    fi
  done

  log_batch_audit "$queue_file" "$total"
  rm -f "$queue_file"

  vj_state_set "$JOB" PHASE "finished"
  vj_state_set "$JOB" CURRENT ""
  log "VJ batch download finished"
  vj_print_summary "$JOB" "$LOG" "YouTube VJ batch"
}

main "$@"
