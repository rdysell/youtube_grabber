The default is now a full-length **1280×720 H.264 MP4 with no audio**, and the frame rate is capped at **24 fps**. Length is left alone so you can cut the 6–10 second loops afterwards.

That is the size this show was built for. Fosfora scales it up to the 1080p projector, and a 1080p file would cost about two and a quarter times the memory without making the picture usefully sharper. 24 fps is the top of the 15–24 range, so a 10 second loop is about 0.8 GB and two of them can sit on screen together. A source that is already 15 fps stays at 15. A 30 or 60 fps source is brought down to 24. Anything that is not 16:9 is padded to 1280×720, not stretched.

On the aurora video, yt-dlp now picks format `398`: 1280×720, 30 fps, video only. The encode step then writes a 24 fps H.264 MP4 and drops the audio.

The rule is in `~/.config/yt-dlp/config`. The encode is `~/.config/yt-dlp/vj-720.sh`, which runs after each download. The finished file still lands in the YouTube iCloud folder. A long video will take a while to encode on this iMac after the download finishes.

Yes. A time range downloads only that slice, not the whole video. ffmpeg seeks to the start time and stops at the end. The 720p H.264 step then runs on that slice only.

Pass the range on that one command. Leave it out of the config, because most links in `docs/youtube_links` have no clip note and should stay full length.

```sh
yt-dlp --download-sections "*0:20-0:30" --force-keyframes-at-cuts "https://youtu.be/qeWLeTQAjzU"
```

The `*` marks a time range. `0:20-0:30` is 10 seconds starting 20 seconds in. `--force-keyframes-at-cuts` makes the cut land on those exact times. Without it, YouTube only cuts on keyframes, so the clip can start a few seconds early.

The notes in your list map to these ranges:

| Clip                                                           | Range              |
| -------------------------------------------------------------- | ------------------ |
| Calm river, first fireplace, campfire by the river             | `*0:20-0:30`       |
| Campfire in the snow                                           | `*1:00:00-1:00:10` |
| Winter cabins and stormy ocean, where no start time is written | `*0:00-0:10`       |

The calm river link is a live URL (`youtube.com/live/...`). A time range works there only if YouTube is serving a finished recording. An ongoing live stream has no fixed start to seek to.

# Background context

Optimal VJ film clips follow these specs:
Ok, help me picj the format as default to fit this VJ specs. Ignore the length of the video, but this means I only need to cut it up in lengths afterwwards.

Make the files **1280×720, 16:9, 6–10 seconds, 15–24 fps, H.264 MP4, no audio.** The projector still runs at 1080p. Fosfora scales the clip up. A 1080p source does not make the projected image sharper in a useful way here, and it costs about two and a quarter times as much memory.

Length still matters at 720p, because every frame is stored. At that resolution one frame is about 3.5 MB:

| Clip           | Unpacked size |
| -------------- | ------------- |
| 6 s at 15 fps  | about 0.3 GB  |
| 8 s at 18 fps  | about 0.5 GB  |
| 10 s at 24 fps | about 0.8 GB  |

That range is the one this show was built for. Two of those can sit on screen together, including while one scene dissolves into the next.

One clip can go longer before the app refuses it: at 720p and 24 fps the hard line is about **24 seconds**, and at 15 fps about **39 seconds**. Stay at 6–10 seconds anyway. A longer loop fills the same 6 GB pool the rest of the scene needs, and that is what slowed the picture last time.

If one shot really has to be 1080p, keep it to **about 6 seconds at 15 fps** (about 0.7 GB). A 1080p clip at 24 fps only has room for about 10 seconds before it hits the 2 GB per-clip limit, and then there is little left for a second video layer.
