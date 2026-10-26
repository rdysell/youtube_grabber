#!/bin/bash
# Wrap VJ batch scripts with RAM ulimit + CPU cap for the whole job tree.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=vj-limits.sh
source "${SCRIPT_DIR}/vj-limits.sh"

if [[ $# -lt 1 ]]; then
  echo "Usage: vj-run-limited.sh <command> [args...]" >&2
  exit 1
fi

mkdir -p "${HOME}/.config/yt-dlp"
cp -f "${SCRIPT_DIR}/vj-limits.sh" "${HOME}/.config/yt-dlp/vj-limits.sh"
cp -f "${SCRIPT_DIR}/vj-filename.sh" "${HOME}/.config/yt-dlp/vj-filename.sh"
cp -f "${SCRIPT_DIR}/vj-720.sh" "${HOME}/.config/yt-dlp/vj-720.sh"
chmod +x "${HOME}/.config/yt-dlp/vj-720.sh"

vj_apply_shell_limits
vj_warn_if_no_cpulimit

if command -v cpulimit >/dev/null; then
  exec cpulimit -l "$(vj_cpulimit_value)" -z -- "$@"
fi
if command -v taskpolicy >/dev/null; then
  exec taskpolicy -b "$@"
fi
exec nice -n 15 "$@"
