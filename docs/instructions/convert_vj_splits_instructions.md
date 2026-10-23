# Split one video into clips

Stream copy with FFmpeg. The original file stays where it is. Resolution, codec, frame rate, and quality stay as they are. The default clip length is 55 seconds. `make convert-vj-splits-20s` uses 20 seconds, and any whole number from 1 to 86400 works the same way (`make convert-vj-splits-10s`). Cuts land on keyframes, so a clip can be a little shorter or longer than the length you asked for. Filenames use the boundaries FFmpeg actually wrote.

## Run

From the **repo root**:

| Command | Job |
|---------|-----|
| `make convert-vj-splits` | Ask for a path, then split into ~55s clips |
| `make convert-vj-splits-20s` | Same, with 20-second clips. Replace `20` with any whole number |
| `make convert-vj-splits-status` | Running? progress %, current clip, log tail |
| `make convert-vj-splits-stop` | Stop immediately (keep finished clips) |
| `make convert-vj-splits-stop-next` | Finish the current clip, then stop |

```sh
make convert-vj-splits
```

Paste a full path when asked. In Finder, select the video and press **Option + Command + C**. A paste that still has backslashes before spaces is fine.

Log: `~/.cache/yt-dlp/convert-vj-splits.log` — state: `~/.cache/yt-dlp/convert-vj-splits.{pid,state}`.

Only one split at a time. The prompt returns as soon as the path checks out. Use `make convert-vj-splits-status` for progress.

## What the script does

1. Checks the file is on disk (an iCloud file that is not downloaded yet is refused) and has a video stream.
2. Makes a short folder **next to the source file**. The name is a few title words, the YouTube id when the file has one, then `_clips` (for example `Abstract_Liquid_jgm58cbu0kw_clips`). An older long clips folder for that same file is renamed to this short name.
3. Copies the video into clips of the length you asked for (`-c copy`, no re-encode). Default is about 55 seconds.
4. Renames each clip from FFmpeg's recorded start and end.

Clip names use that same short title, then the real start and end: `Abstract_Liquid__0h-05-33_to_0h-06-25.mp4`. Hours drop the leading zero and keep an `h`. Spaces and dots become `_`. Other characters outside letters, numbers, `_`, and `-` are removed. The cut prefers a `_` so the name does not end mid-word.

Example:

`1_Hour_of_Natural_Patterns_Ferns_Agate_Sea_Fans_River_Deltas_Rel_y8ONlczgiXA_1280x720_vj.mp4`

becomes a folder

`1_Hour_of_Natural_y8ONlczgiXA_clips`

and files

`1_Hour_of_Natural__0h-00-00_to_0h-00-55.mp4`

Running the command again on the **same** file replaces the clips in that folder. A different file that would shorten to the same name gets `_clips_2`.

## Stop

| Command | What you keep |
|---------|----------------|
| `make convert-vj-splits-stop` | Clips already finished. The one still being written is discarded. |
| `make convert-vj-splits-stop-next` | Finished clips, plus the one in progress once it closes. Nothing after that. |

Requires `ffmpeg` and `ffprobe` on the PATH (`brew install ffmpeg`).
