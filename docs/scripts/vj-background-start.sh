#!/bin/bash
# Start a VJ job detached so make returns immediately.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=vj-job-common.sh
source "${SCRIPT_DIR}/vj-job-common.sh"

usage() {
  echo "Usage: vj-background-start.sh <job-id> <status-make-target> <log-path> <command...>" >&2
  exit 1
}

[[ $# -ge 4 ]] || usage

JOB="$1"
STATUS_MAKE="$2"
LOG="$3"
shift 3

if running=$(vj_job_running_pid "$JOB" 2>/dev/null); then
  echo "${JOB}: already running (pid ${running})."
  echo "  Status: ${STATUS_MAKE}"
  exit 1
fi

mkdir -p "${VJ_CACHE}"
nohup env VJ_BACKGROUND=1 "$@" >>"${VJ_CACHE}/${JOB}.nohup.out" 2>&1 &
disown 2>/dev/null || true

sleep 1
if running=$(vj_job_running_pid "$JOB" 2>/dev/null); then
  vj_print_job_banner "${JOB} (background)" "${STATUS_MAKE}" "${LOG}"
  echo "  PID:    ${running}"
  echo "  Tip:    this terminal is free; use ${STATUS_MAKE} anytime."
else
  echo "${JOB}: failed to start. Check ${VJ_CACHE}/${JOB}.nohup.out and ${LOG}" >&2
  if [[ -f "${VJ_CACHE}/${JOB}.nohup.out" ]]; then
    echo "  --- last lines of nohup ---" >&2
    tail -5 "${VJ_CACHE}/${JOB}.nohup.out" | sed 's/^/    /' >&2
  fi
  exit 1
fi
