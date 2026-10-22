# VJ commands cheat sheet

Run everything from the **repo root** (`youtube_grabber/`).

## YouTube queue

| Command | Action |
|---------|--------|
| `make youtube-vj` | Download & encode queue (`docs/1_youtube_links_to_download.md`) |
| `make youtube-vj-status` | Running? progress %, current URL, log tail |
| `make youtube-vj-stop` | Stop batch + yt-dlp/ffmpeg children |

- **Output:** `~/Library/Mobile Documents/com~apple~CloudDocs/VJ-Movies/YouTube/<group>/`
- **Log:** `~/.cache/yt-dlp/vj-batch.log`
- **State:** `~/.cache/yt-dlp/youtube-vj.{pid,state}`
- **Details:** [docs/instructions/vj_download_instructions.md](docs/instructions/vj_download_instructions.md)

Safe to re-run; skips files already on disk. Only **one** `make youtube-vj` at a time. Prints a **summary** when the run finishes (or after `-stop`).

## Local file convert

| Command | Action |
|---------|--------|
| `make convert-vj` | Convert inbox → VJ MP4 |
| `make convert-vj-status` | Running? progress %, current file, log tail |
| `make convert-vj-stop` | Stop convert + ffmpeg children |

| Folder | Role |
|--------|------|
| `~/Library/Mobile Documents/com~apple~CloudDocs/VJ-Movies/Convert_these_media_files` | Inbox (drop files here) |
| `~/Library/Mobile Documents/com~apple~CloudDocs/VJ-Movies/Converted_media_files` | VJ-ready output |
| `~/Library/Mobile Documents/com~apple~CloudDocs/VJ-Movies/Converted_source_files` | Originals after success |

- **Log:** `~/.cache/yt-dlp/convert-vj.log`
- **State:** `~/.cache/yt-dlp/convert-vj.{pid,state}`
- **Details:** [docs/instructions/convert_to_vj_format_instructions.md](docs/instructions/convert_to_vj_format_instructions.md)

Safe to re-run; skips when a valid output already exists. Prints a **summary** when the run finishes (or after `-stop`).

## Tips

- **CPU:** One encode at a time is easiest on the iMac; avoid two heavy jobs together.
- **OK together:** `make youtube-vj` while `make convert-vj` is fine if load is acceptable; never two `youtube-vj` runs.
- **Progress %** = items done in the **current** run (not ffmpeg % inside one long file).
- **Scripts:** `docs/scripts/` (`vj-download-all.sh`, `convert-vj`, status/stop helpers).

## Output spec (both pipelines)

1280×720, 16:9 pad, H.264 MP4, no audio, ≤24 fps — same as `~/.config/yt-dlp/vj-720.sh`.
