# Canonical VJ library root on Elephant (local disk — not iCloud).
# Override: export VJ_ROOT=/other/path
# VJ_MOVIES_ROOT is a legacy env alias for VJ_ROOT.
if [[ -n "${VJ_MOVIES_ROOT:-}" && -z "${VJ_ROOT:-}" ]]; then
  VJ_ROOT="${VJ_MOVIES_ROOT}"
fi
VJ_ROOT="${VJ_ROOT:-/Volumes/Elephant/VJ}"
VJ_YOUTUBE="${VJ_ROOT}/YouTube"
VJ_CONVERT_INBOX="${VJ_ROOT}/Convert_these_media_files"
VJ_CONVERT_OUTBOX="${VJ_ROOT}/Converted_media_files"
VJ_CONVERT_ARCHIVE="${VJ_ROOT}/Converted_source_files"
# Keep alias so old shell exports still work after sourcing.
VJ_MOVIES_ROOT="${VJ_ROOT}"
