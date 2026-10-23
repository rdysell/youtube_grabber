# VJ commands cheat sheet

Run everything from the **repo root** (`youtube_grabber/`).

## YouTube queue

| Command                                      | Action                                                   |
| -------------------------------------------- | -------------------------------------------------------- |
| `make youtube-vj` or `make youtube-vj-start` | Download & encode queue (quiet; use status for progress) |
| `make youtube-vj-status`                     | Running? progress %, current URL, log tail               |
| `make youtube-vj-stop`                       | Stop immediately (kills current encode)                  |
| `make youtube-vj-stop-next`                  | Finish **current** item, then stop                       |
| `make youtube-vj-restart-next`               | Stop after current item, wait, then **start** (reload scripts) |

- **Output:** `~/Library/Mobile Documents/com~apple~CloudDocs/VJ-Movies/YouTube/<group>/`
- **Names:** `Short_Title_VIDEO_ID_1280x720_vj.mp4` (ASCII, underscores). Rename an existing library: `docs/scripts/vj-rename-youtube-library.sh`. Refresh paths in the done list: `docs/scripts/vj-sync-done-paths.sh`.
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
| `make convert-vj-restart-next`               | Stop after current file, wait, then **start** (reload scripts) |

| Folder                                                                               | Role                    |
| ------------------------------------------------------------------------------------ | ----------------------- |
| `~/Library/Mobile Documents/com~apple~CloudDocs/VJ-Movies/Convert_these_media_files` | Inbox (drop files here) |
| `~/Library/Mobile Documents/com~apple~CloudDocs/VJ-Movies/Converted_media_files`     | VJ-ready output         |
| `~/Library/Mobile Documents/com~apple~CloudDocs/VJ-Movies/Converted_source_files`    | Originals after success |

- **Log:** `~/.cache/yt-dlp/convert-vj.log`
- **State:** `~/.cache/yt-dlp/convert-vj.{pid,state}`
- **Details:** [docs/instructions/convert_to_vj_format_instructions.md](docs/instructions/convert_to_vj_format_instructions.md)

Safe to re-run; skips when a valid output already exists. **Starts in the background** like YouTube batch. Use `make convert-vj-status` for progress.

## Split one video into clips (default 55 seconds)

| Command                                                    | Action                                                              |
| ---------------------------------------------------------- | ------------------------------------------------------------------- |
| `make convert-vj-splits` or `make convert-vj-splits-start` | Ask for a file path, then split it into ~55s clips                  |
| `make convert-vj-splits-10s`                               | Same, with ~10s clips                                               |
| `make convert-vj-splits-20s`                               | Same, with ~20s clips                                               |
| `make convert-vj-splits-status`                            | Running? progress %, current clip, source, output folder, log tail |
| `make convert-vj-splits-stop`                              | Stop immediately (keeps finished clips, drops the one in progress)  |
| `make convert-vj-splits-stop-next`                         | Finish the **current** clip, then stop                              |

Any whole number of seconds works the same way: `make convert-vj-splits-30s` is ~30s clips. From 1 to 86400.

- Paste a full path when asked. Finder: select the video, then **Option + Command + C**. A paste with backslashes before spaces is fine.
- **Output:** a short `*_clips` folder next to that file. The folder keeps a few title words plus the YouTube id when the file has one (`Abstract_Liquid_jgm58cbu0kw_clips`). The original stays where it is. This is a stream copy: resolution, codec, and quality stay as they are in the source (it does not re-encode to the 720p spec below).
- **Names:** the same short title as the folder, then the real span. Example: `Abstract_Liquid__0h-05-33_to_0h-06-25.mp4`. Hours are not zero-padded (`0h`, `1h`). Minutes and seconds stay two digits.
- **Clips:** the number before the final `s` (`10s` is 10 seconds, `20s` is 20). Default is 55. Cuts land on keyframes, so a clip can be a little shorter or longer than the length you asked for.
- **Log:** `~/.cache/yt-dlp/convert-vj-splits.log`
- **State:** `~/.cache/yt-dlp/convert-vj-splits.{pid,state}`
- **Details:** [docs/instructions/convert_vj_splits_instructions.md](docs/instructions/convert_vj_splits_instructions.md)

The terminal comes back after the path is accepted. Use `make convert-vj-splits-status` for progress. Running it again on the **same** file replaces that clips folder. Only one `make convert-vj-splits` at a time.

Example, `YouTube/Abstract fluids/1_Hour_of_Natural_Patterns_Ferns_Agate_Sea_Fans_River_Deltas_Rel_y8ONlczgiXA_1280x720_vj.mp4` (1:00:06) → 66 files in:

`.../Abstract fluids/1_Hour_of_Natural_y8ONlczgiXA_clips/`

`1_Hour_of_Natural__0h-00-00_to_0h-00-55.mp4`  
`1_Hour_of_Natural__0h-59-39_to_1h-00-06.mp4`

## Resource limits

Each `make youtube-vj` / `make convert-vj` / `make convert-vj-splits` run is wrapped with:

- **CPU:** ~**40%** of total cores (`ffmpeg -threads` + `cpulimit`).
- **RAM:** **30 GiB** ulimit on **Linux** only. **macOS cannot set a per-process RAM cap** (Darwin ignores `ulimit -v`); rely on CPU limits and avoid running two heavy encodes at once.

Install stricter CPU cap: `brew install cpulimit` (otherwise `nice` + thread cap only).  
Tunables: `docs/scripts/vj-limits.sh` (copied to `~/.config/yt-dlp/vj-limits.sh` on each run).

## Tips

- **CPU:** One encode at a time is easiest on the iMac; avoid two heavy jobs together.
- **OK together:** `make youtube-vj` while `make convert-vj` is fine if load is acceptable; never two `youtube-vj` runs. `make convert-vj-splits` is a stream copy (lighter than an encode) and can run beside them; still only one splits job at a time.
- **After `git pull`:** `make youtube-vj-restart-next` or `make convert-vj-restart-next` reloads scripts without killing a long encode mid-file.
- **Progress %** = items done in the **current** run (not ffmpeg % inside one long file). For splits, one item is one clip.
- **Scripts:** `docs/scripts/` (`vj-download-all.sh`, `convert-vj`, `convert-vj-splits`, status/stop helpers).

## Output spec (youtube-vj and convert-vj)

1280×720, 16:9 pad, H.264 MP4, no audio, ≤24 fps — same as `~/.config/yt-dlp/vj-720.sh`.

`make convert-vj-splits` does not use this spec. It copies the source file as-is into clips (55s, or the length in the command name).
