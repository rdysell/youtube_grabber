# Shared helpers for youtube-vj / convert-vj (status, stop, progress).
VJ_CACHE="${HOME}/.cache/yt-dlp"

vj_pid_file() { echo "${VJ_CACHE}/$1.pid"; }
vj_state_file() { echo "${VJ_CACHE}/$1.state"; }

vj_state_set() {
  local job="$1" key="$2" val="$3" f
  f=$(vj_state_file "$job")
  mkdir -p "$VJ_CACHE"
  touch "$f"
  if grep -q "^${key}=" "$f" 2>/dev/null; then
    sed -i '' "s|^${key}=.*|${key}=${val}|" "$f"
  else
    echo "${key}=${val}" >>"$f"
  fi
}

vj_state_get() {
  local job="$1" key="$2" f val
  f=$(vj_state_file "$job")
  if [[ ! -f "$f" ]]; then
    return 0
  fi
  val=$(grep "^${key}=" "$f" 2>/dev/null | tail -1 | cut -d= -f2- || true)
  printf '%s' "$val"
}

vj_job_running_pid() {
  local job="$1" pf pid
  pf=$(vj_pid_file "$job")
  [[ -f "$pf" ]] || return 1
  pid=$(<"$pf")
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null || return 1
  echo "$pid"
}

vj_job_acquire_pid() {
  local job="$1" running
  mkdir -p "$VJ_CACHE"
  if running=$(vj_job_running_pid "$job"); then
    echo "Already running (pid ${running}). Use: make ${job}-stop" >&2
    exit 1
  fi
  rm -f "$(vj_pid_file "$job")"
  echo $$ >"$(vj_pid_file "$job")"
  trap "rm -f '$(vj_pid_file "$job")'" EXIT
}

vj_kill_tree() {
  local pid="$1" child
  [[ -n "$pid" ]] || return 0
  for child in $(pgrep -P "$pid" 2>/dev/null); do
    vj_kill_tree "$child"
  done
  kill "$pid" 2>/dev/null || true
}

vj_job_stop() {
  local job="$1" pid
  pid=$(vj_job_running_pid "$job" || true)
  if [[ -z "$pid" ]]; then
    echo "${job}: not running"
    rm -f "$(vj_pid_file "$job")"
    return 0
  fi
  echo "Stopping ${job} (pid ${pid}) and child processes..."
  vj_kill_tree "$pid"
  sleep 2
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$(vj_pid_file "$job")"
  vj_state_set "$job" PHASE "stopped"
  echo "${job}: stopped"
  case "$job" in
    youtube-vj)
      vj_print_summary "$job" "${VJ_CACHE}/vj-batch.log" "YouTube VJ batch"
      ;;
    convert-vj)
      vj_print_summary "$job" "${VJ_CACHE}/convert-vj.log" "Local VJ convert"
      ;;
  esac
}

vj_print_status() {
  local job="$1" log="$2" label="$3"
  local pid total done pct phase current
  pid=$(vj_job_running_pid "$job" || true)
  total=$(vj_state_get "$job" TOTAL)
  done=$(vj_state_get "$job" DONE)
  phase=$(vj_state_get "$job" PHASE)
  current=$(vj_state_get "$job" CURRENT)

  echo "${label}"
  if [[ -n "$pid" ]]; then
    echo "  State:    RUNNING (pid ${pid})"
  else
    echo "  State:    not running"
  fi
  if [[ -n "$phase" ]]; then
    echo "  Phase:    ${phase}"
  fi
  if [[ -n "$total" && "$total" =~ ^[0-9]+$ ]]; then
    done=${done:-0}
    if [[ "$done" =~ ^[0-9]+$ && "$total" -gt 0 ]]; then
      pct=$((done * 100 / total))
      echo "  Progress: ${done}/${total} (${pct}%)"
    else
      echo "  Progress: ?/${total}"
    fi
  fi
  if [[ -n "$current" ]]; then
    echo "  Current:  ${current}"
  fi
  echo "  Log:      ${log}"
  if [[ -f "$log" ]]; then
    echo "  --- log (last 8 job lines) ---"
    { grep -E '^\[20[0-9]{2}-|^(ENCODE|OK|SKIP|FAIL|ARCHIVE|Removed)' "$log" 2>/dev/null || tail -20 "$log"; } | tail -8 | sed 's/^/    /'
  fi
}

vj_stop_after_current_request() {
  local job="$1" label="$2"
  if ! vj_job_running_pid "$job" >/dev/null; then
    echo "${label}: not running."
    exit 1
  fi
  vj_state_set "$job" STOP_AFTER 1
  echo "${label}: will stop after the current item finishes."
}

vj_maybe_stop_after_current() {
  local job="$1" log="$2" summary_title="$3"
  if [[ "$(vj_state_get "$job" STOP_AFTER)" != "1" ]]; then
    return 0
  fi
  vj_state_set "$job" STOP_AFTER 0
  vj_state_set "$job" PHASE "stopped_after_current"
  vj_state_set "$job" CURRENT ""
  {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stop-after-current: exiting before next item."
  } >>"$log"
  vj_print_summary "$job" "$log" "$summary_title"
  exit 0
}

vj_bump_done() {
  local job="$1" done total
  done=$(vj_state_get "$job" DONE)
  done=${done:-0}
  done=$((done + 1))
  vj_state_set "$job" DONE "$done"
  total=$(vj_state_get "$job" TOTAL)
  if [[ -n "$total" && "$total" =~ ^[0-9]+$ && "$done" -ge "$total" ]]; then
    vj_state_set "$job" PHASE "finished"
  fi
}

# Short CLI report when a job finishes or is stopped (printed to stdout).
vj_print_summary() {
  local job="$1" log="$2" title="$3"
  local total done phase pct fails remain

  total=$(vj_state_get "$job" TOTAL)
  done=$(vj_state_get "$job" DONE)
  phase=$(vj_state_get "$job" PHASE)
  fails=0
  if [[ -f "$log" ]]; then
    fails=$(grep -cE '\] FAIL |^FAIL ' "$log" 2>/dev/null || true)
    fails=${fails:-0}
  fi

  echo ""
  echo "── ${title} — summary ──"
  case "${phase}" in
    finished) echo "  Result:   completed" ;;
    stopped) echo "  Result:   stopped early" ;;
    stopped_after_current) echo "  Result:   stopped after current item" ;;
    *) echo "  Result:   ${phase:-done}" ;;
  esac
  if [[ -n "$total" && "$total" =~ ^[0-9]+$ ]]; then
    done=${done:-0}
    if [[ "$total" -gt 0 ]]; then
      pct=$((done * 100 / total))
      echo "  Progress: ${done}/${total} items (${pct}%)"
      remain=$((total - done))
      if [[ "$remain" -gt 0 ]]; then
        echo "  Skipped:  ${remain} item(s) failed or not completed"
      fi
    else
      echo "  Progress: 0 items in queue"
    fi
  fi
  if [[ "$fails" -gt 0 ]]; then
    echo "  Failures: ${fails} (see log)"
  fi
  echo "  Log:      ${log}"
  echo "  Status:   make ${job}-status"
  echo "────────────────────────────"
  echo ""
}
