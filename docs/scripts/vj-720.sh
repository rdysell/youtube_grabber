#!/bin/sh
# Fit a downloaded video to the Fosfora VJ spec, then rename to a system-friendly filename.
# Installed to ~/.config/yt-dlp/vj-720.sh on each VJ batch run (see vj-run-limited.sh).
set -eu

if [ -f "${HOME}/.config/yt-dlp/vj-limits.sh" ]; then
  # shellcheck source=/dev/null
  . "${HOME}/.config/yt-dlp/vj-limits.sh"
fi
if [ -f "${HOME}/.config/yt-dlp/vj-filename.sh" ]; then
  # shellcheck source=/dev/null
  . "${HOME}/.config/yt-dlp/vj-filename.sh"
fi

in=$1
yt_id=${2:-}
yt_title=${3:-}
dir=$(dirname "$in")
base=$(basename "$in")
stem=${base%.*}
out="$dir/$stem.mp4"
tmp="${HOME}/.cache/yt-dlp/${stem}.$$.mp4"

mkdir -p "${HOME}/.cache/yt-dlp"

if type vj_run_ffmpeg >/dev/null 2>&1; then
  vj_run_ffmpeg -y -i "$in" \
    -an \
    -vf "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=fps='min(source_fps\,24)'" \
    -c:v libx264 -pix_fmt yuv420p -profile:v high -level:v 4.0 \
    -crf 18 -preset fast \
    -movflags +faststart \
    "$tmp"
else
  ffmpeg -nostdin -y -hide_banner -loglevel error -i "$in" \
    -an \
    -vf "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=fps='min(source_fps\,24)'" \
    -c:v libx264 -pix_fmt yuv420p -profile:v high -level:v 4.0 \
    -crf 18 -preset fast \
    -movflags +faststart \
    "$tmp"
fi

if [ "$in" != "$out" ]; then
  rm -f "$in"
fi
mv -f "$tmp" "$out"

if type vj_finalize_youtube_file >/dev/null 2>&1; then
  vj_finalize_youtube_file "$out" "$yt_id" "$yt_title" >/dev/null
fi
