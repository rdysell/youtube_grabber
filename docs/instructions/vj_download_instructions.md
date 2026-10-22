# VJ YouTube downloads

Clips for Fosfora VJ backgrounds (projector at 1080p; Fosfora scales sources up).

## Queue

| File | Purpose |
|------|---------|
| `docs/1_youtube_links_to_download.md` | URLs still to fetch (per-line notes for clip timing) |
| `docs/2_youtube_links_done.md` | Finished items with YouTube title, URL, iCloud path, size, duration |

**Output:** `~/Library/Mobile Documents/com~apple~CloudDocs/VJ-Movies/YouTube/<group>/`  
`<group>` is the `# Heading` in the queue (e.g. `Abstract fluids`).

When a download finishes, remove its URL from `1_…` and record it in `2_…` under the same group (use `# Misc` if needed).

## Batch script (preferred)

From the **repo root**:

| Command | Action |
|---------|--------|
| `make youtube-vj` | Run batch download |
| `make youtube-vj-status` | Running? progress %, current item, log tail |
| `make youtube-vj-stop` | Stop batch and child yt-dlp/ffmpeg |

```sh
make youtube-vj
```

Scripts live in `docs/scripts/`. State: `~/.cache/yt-dlp/youtube-vj.{pid,state}`.

- Uses `~/.config/yt-dlp/config` and post-encode `~/.config/yt-dlp/vj-720.sh`
- Short section clips first, then shorter full videos, then long sources
- Skips files already present (by YouTube id in the filename)
- Updates the two queue docs after each success
- Log: `~/.cache/yt-dlp/vj-batch.log`

Safe to re-run if the Mac sleeps or the job stops.

## Default format (download + encode)

| Setting | Value |
|---------|--------|
| Resolution | **1280×720**, 16:9 (letterbox pad, no stretch) |
| Codec | **H.264** MP4, **no audio** |
| Frame rate | **≤24 fps** (15 fps sources stay 15; 30/60 → 24) |
| Length | **Full video** unless the queue asks for a section (trim to 6–10 s loops in Fosfora later) |

yt-dlp: video only, max 720p (`~/.config/yt-dlp/config`). Encode runs automatically after each file moves to iCloud. Long sources take a long time to encode on the iMac.

**Why 720p:** ~2.25× less memory than 1080p for little visible gain on this projector. Target loops: **6–10 s at 15–24 fps** (~0.3–0.8 GB unpacked per loop; two loops on screen is the design budget). Hard limits in app: ~24 s @ 24 fps / ~39 s @ 15 fps at 720p—still prefer 6–10 s.

## Section clips (only when noted in the queue)

Pass range on the **command**, not in global config:

```sh
yt-dlp --download-sections "*0:20-0:30" --force-keyframes-at-cuts \
  -P "$HOME/Library/Mobile Documents/com~apple~CloudDocs/VJ-Movies/YouTube/Fireplace" \
  "https://youtu.be/qeWLeTQAjzU"
```

`*` = section syntax. `--force-keyframes-at-cuts` avoids starting early on keyframe-only cuts.

| Queue note | Range |
|------------|--------|
| Calm river, first fireplace, campfire by the river | `*0:20-0:30` |
| Campfire in the snow | `*1:00:00-1:00:10` |
| Winter cabins, stormy ocean (no start time) | `*0:00-0:10` |

`youtube.com/live/…` sections work only when YouTube serves a **finished** recording, not a live stream.

Local files (not YouTube): see [convert_to_vj_format_instructions.md](./convert_to_vj_format_instructions.md) and `docs/scripts/convert-vj`.

## One-off download

Same as config defaults; set `-P` to the group folder:

```sh
yt-dlp -P "$HOME/Library/Mobile Documents/com~apple~CloudDocs/VJ-Movies/YouTube/Aurora" \
  "https://youtu.be/miqbNFmbN2Q"
```
