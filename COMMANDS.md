# VJ commands cheat sheet

Run everything from the **repo root** (`youtube_grabber/`).

## YouTube queue

| Command                                      | Action                                                   |
| -------------------------------------------- | -------------------------------------------------------- |
| `make youtube-vj` or `make youtube-vj-start` | Download & encode queue (quiet; use status for progress) |
| `make youtube-vj-status`                     | Running? progress %, current URL, log tail               |
| `make youtube-vj-stop`                       | Stop immediately (kills current encode)                  |
| `make youtube-vj-stop-next`                  | Finish **current** item, then stop                       |

- **Output:** `~/Library/Mobile Documents/com~apple~CloudDocs/VJ-Movies/YouTube/<group>/`
- **Log:** `~/.cache/yt-dlp/vj-batch.log`
- **State:** `~/.cache/yt-dlp/youtube-vj.{pid,state}`
- **Details:** [docs/instructions/vj_download_instructions.md](docs/instructions/vj_download_instructions.md)

Safe to re-run; skips files already on disk. Only **one** `make youtube-vj` at a time. **Starts in the background**—the terminal prompt returns right away (no log streaming). Use `make youtube-vj-status` or `tail -f` on the log file. Summary is written to the log when the job finishes (or after `-stop`).

## Local file convert

| Command                                      | Action                                                  |
| -------------------------------------------- | ------------------------------------------------------- |
| `make convert-vj` or `make convert-vj-start` | Convert inbox → VJ MP4 (quiet; use status for progress) |
| `make convert-vj-status`                     | Running? progress %, current file, log tail             |
| `make convert-vj-stop`                       | Stop immediately                                        |
| `make convert-vj-stop-next`                  | Finish **current** file, then stop                      |

| Folder                                                                               | Role                    |
| ------------------------------------------------------------------------------------ | ----------------------- |
| `~/Library/Mobile Documents/com~apple~CloudDocs/VJ-Movies/Convert_these_media_files` | Inbox (drop files here) |
| `~/Library/Mobile Documents/com~apple~CloudDocs/VJ-Movies/Converted_media_files`     | VJ-ready output         |
| `~/Library/Mobile Documents/com~apple~CloudDocs/VJ-Movies/Converted_source_files`    | Originals after success |

- **Log:** `~/.cache/yt-dlp/convert-vj.log`
- **State:** `~/.cache/yt-dlp/convert-vj.{pid,state}`
- **Details:** [docs/instructions/convert_to_vj_format_instructions.md](docs/instructions/convert_to_vj_format_instructions.md)

Safe to re-run; skips when a valid output already exists. **Starts in the background** like YouTube batch. Use `make convert-vj-status` for progress.

## Resource limits

Each `make youtube-vj` / `make convert-vj` run is wrapped with:

- **CPU:** ~**40%** of total cores (`ffmpeg -threads` + `cpulimit`).
- **RAM:** **30 GiB** ulimit on **Linux** only. **macOS cannot set a per-process RAM cap** (Darwin ignores `ulimit -v`); rely on CPU limits and avoid running two heavy encodes at once.

Install stricter CPU cap: `brew install cpulimit` (otherwise `nice` + thread cap only).  
Tunables: `docs/scripts/vj-limits.sh` (copied to `~/.config/yt-dlp/vj-limits.sh` on each run).

## Tips

- **CPU:** One encode at a time is easiest on the iMac; avoid two heavy jobs together.
- **OK together:** `make youtube-vj` while `make convert-vj` is fine if load is acceptable; never two `youtube-vj` runs.
- **Progress %** = items done in the **current** run (not ffmpeg % inside one long file).
- **Scripts:** `docs/scripts/` (`vj-download-all.sh`, `convert-vj`, status/stop helpers).

## Output spec (both pipelines)

1280×720, 16:9 pad, H.264 MP4, no audio, ≤24 fps — same as `~/.config/yt-dlp/vj-720.sh`.
