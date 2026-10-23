#!/bin/bash
# Stop after current item (if running), wait, then start job in background with fresh scripts.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=vj-job-common.sh
source "${SCRIPT_DIR}/vj-job-common.sh"

usage() {
  echo "Usage: vj-restart-next.sh <job-id> <status-make-target> <log-path> <command...>" >&2
  exit 1
}

[[ $# -ge 4 ]] || usage

JOB="$1"
STATUS_MAKE="$2"
LOG="$3"
shift 3

label_for_job() {
  case "$1" in
    youtube-vj) echo "YouTube VJ batch" ;;
    convert-vj) echo "Local VJ convert" ;;
    *) echo "$1" ;;
  esac
}

LABEL=$(label_for_job "$JOB")

if vj_job_running_pid "$JOB" >/dev/null; then
  vj_stop_after_current_request "$JOB" "$LABEL"
  echo "Waiting for ${JOB} to finish the current item..."
  while vj_job_running_pid "$JOB" >/dev/null; do
    sleep 5
  done
  echo "${JOB}: stopped; starting again (latest scripts from repo)."
else
  echo "${JOB}: not running; starting."
fi

exec "${SCRIPT_DIR}/vj-background-start.sh" "$JOB" "$STATUS_MAKE" "$LOG" "$@"
