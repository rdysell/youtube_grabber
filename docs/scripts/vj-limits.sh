# Resource caps for VJ batch jobs (macOS).
# Defaults: 30 GiB virtual memory per job tree, ~40% total CPU (see below).
VJ_MAX_RAM_GB=30
VJ_CPU_PERCENT=40

vj_ncpu() {
  sysctl -n hw.ncpu 2>/dev/null || echo 4
}

# ffmpeg/x264 thread count (~40% of cores, at least 1).
vj_ffmpeg_threads() {
  local ncpu t
  ncpu=$(vj_ncpu)
  t=$((ncpu * VJ_CPU_PERCENT / 100))
  [[ "$t" -lt 1 ]] && t=1
  echo "$t"
}

# cpulimit -l value: on multi-core Macs, limit is %·cores (e.g. 8 cores × 40 → 320).
vj_cpulimit_value() {
  echo $(( $(vj_ncpu) * VJ_CPU_PERCENT ))
}

vj_apply_shell_limits() {
  local mem_kb=$((VJ_MAX_RAM_GB * 1024 * 1024))
  if ulimit -v "$mem_kb" 2>/dev/null; then
    :
  else
    echo "Note: could not set ${VJ_MAX_RAM_GB}G RAM ulimit (continuing)." >&2
  fi
}

vj_warn_if_no_cpulimit() {
  command -v cpulimit >/dev/null && return 0
  echo "Note: install cpulimit for strict CPU cap (brew install cpulimit). Using nice + ffmpeg -threads only." >&2
}

# Run a command under CPU cap when cpulimit is available.
vj_run_cpu_limited() {
  local limit
  limit=$(vj_cpulimit_value)
  if command -v cpulimit >/dev/null; then
    cpulimit -l "$limit" -z -- "$@"
  else
    nice -n 15 "$@"
  fi
}

# ffmpeg with thread cap + CPU limit wrapper.
vj_run_ffmpeg() {
  local threads
  threads=$(vj_ffmpeg_threads)
  vj_run_cpu_limited ffmpeg -hide_banner -loglevel error -threads "$threads" "$@"
}
