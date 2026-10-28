# Convert local files to VJ format

Same end result as [vj_download_instructions.md](./vj_download_instructions.md): **1280×720**, 16:9 (pad, no stretch), **H.264** MP4, **no audio**, **≤24 fps** (15 fps kept; higher capped at 24). Full length preserved.

## Folders (Elephant — local disk, not iCloud)

| Folder | Role |
|--------|------|
| `/Volumes/Elephant/VJ/Convert_these_media_files` | **Inbox** — drop videos here (subfolders OK) |
| `/Volumes/Elephant/VJ/Converted_media_files` | **Output** — VJ-ready MP4s in **subfolders** (one folder per movie / clip group) |
| `/Volumes/Elephant/VJ/Converted_source_files` | **Archive** — original file after successful convert (flat) |

## Run

From the **repo root**:

| Command | Job |
|---------|-----|
| `make convert-vj` | Run convert |
| `make convert-vj-status` | Running? progress %, current file, log tail |
| `make convert-vj-stop` | Stop immediately |
| `make convert-vj-stop-next` | Finish current file, then stop |
| `make convert-vj-restart-next` | Stop after current file, wait, then start again (use after `git pull`) |
| `make youtube-vj` | YouTube queue (see other doc) |

```sh
make convert-vj
```

Log: `~/.cache/yt-dlp/convert-vj.log` — state: `~/.cache/yt-dlp/convert-vj.{pid,state}`.

Safe to re-run: skips work when a valid output already exists (see below).

## What the script does

1. Finds all videos under the inbox (recursive).
2. For each file, builds an output name and writes under **Converted_media_files/**`<movie>/`**:
   - `Baraka.1992.1080p.BluRay.H264.AAC-RARBG.mp4` → `Baraka_1992/Baraka_1992_1280x720_vj.mp4`
   - Split clips (e.g. in `…_clips/` or names with `_00-01-02_to_…`) → same movie folder, one VJ file per clip.
   - Title = first dot-separated segment; year = first `YYYY` in the name; dots → `_`.
3. **Skip encode** if a valid VJ file already exists in that movie folder (or legacy flat path in **Converted_media_files**).
4. Otherwise ffmpeg encodes (same filter as `~/.config/yt-dlp/vj-720.sh`).
5. On success, **moves** the source into **Converted_source_files** (flat, no subfolders), renamed and shortened if needed:
   - `Koyaanisqatsi.1982.REMASTERED.1080p.BluRay.H264.AAC-LAMA.mp4` →  
     `Koyaanisqatsi_1982_REMASTERED_1080p_vj-processed_org_file.mp4`
   - All `.` in the basename become `_`; suffix `_vj-processed_org_file` before the extension.
6. In the source’s folder, **deletes** non-video sidecars (`.srt`, `.nfo`, `.txt`, etc.). Other videos in that folder are left for their own pass.
7. Removes empty directories under the inbox.

Name collisions in output or archive get `_2`, `_3`, …

## Agent / manual workflow

1. Copy the file(s) into **Convert_these_media_files**.
2. Run `make convert-vj` (or ask an agent to run the script).
3. Use clips from **Converted_media_files** (inside each movie subfolder); originals sit in **Converted_source_files**.

To group **existing** flat outputs: `docs/scripts/vj-organize-converted-outbox.sh`.

Requires `ffmpeg` and `ffprobe` on the PATH.

## Split a finished file into 55-second clips

`make convert-vj-splits` asks for one video path, or a folder of videos, and writes clips next to that file or into grouped subfolders. `make convert-vj-splits-20s` uses 20-second clips (any whole number of seconds works). See [convert_vj_splits_instructions.md](./convert_vj_splits_instructions.md).
