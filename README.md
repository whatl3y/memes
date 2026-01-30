# Meme Generator

Create meme videos by combining video or static images with audio. Runs entirely in Docker - no dependencies to install on your machine.

## Features

- **Video + Audio** — Merge any video file with a separate audio track
- **Image + Audio** — Turn a static image (PNG, JPEG, BMP, TIFF, WebP) into a video with audio
- **Tweet + Audio** — Download a video from a Twitter/X post and use it as input
- **Animated GIF + Audio** — Use animated GIFs as video input, preserving their animation
- **Meme captions** — Add top and/or bottom text overlays in classic meme style
- **Video/GIF looping** — Automatically loops short videos or GIFs to fill the specified duration
- **Audio looping** — Loop short audio clips to match the video length
- **Custom duration** — Trim or extend output to an exact length in seconds
- **YouTube audio download** — Download audio from YouTube videos using yt-dlp
- **Audio trimming** — Extract a specific time range from downloaded audio (start/end points)
- **MP4 output** — H.264 video + AAC audio, optimized for social media with `faststart`
- **Fully Dockerized** — No local dependencies required beyond Docker

### Example

<video src="https://github.com/user-attachments/assets/2db6b0cb-d1c3-4a65-8f6c-ecf27a8793a5" width="400" controls autoplay loop></video>

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)

## Build

```sh
docker build -t meme-maker .
```

## Usage

All commands use volume mounts to pass files in and get the result out.
The output file is written inside the container to `/output/` which you
mount to a local directory so the file appears on your machine.

### Video + Audio

Merge a video file with a separate audio track.

```sh
docker run --rm \
  -v /absolute/path/to/inputs:/input:ro \
  -v /absolute/path/to/output:/output \
  meme-maker \
  --input /input/clip.mp4 \
  --audio /input/song.mp3
```

The result will be at `/absolute/path/to/output/meme.mp4`.

#### Custom output filename

```sh
docker run --rm \
  -v /absolute/path/to/inputs:/input:ro \
  -v /absolute/path/to/output:/output \
  meme-maker \
  --input /input/clip.mp4 \
  --audio /input/song.mp3 \
  --output /output/my-meme.mp4
```

#### Specify duration

Trim or cap the output video to a specific length in seconds.

```sh
docker run --rm \
  -v /absolute/path/to/inputs:/input:ro \
  -v /absolute/path/to/output:/output \
  meme-maker \
  --input /input/clip.mp4 \
  --audio /input/song.mp3 \
  --duration 10
```

#### Loop short audio

If your audio clip is shorter than the video, loop it to fill the entire duration.

```sh
docker run --rm \
  -v /absolute/path/to/inputs:/input:ro \
  -v /absolute/path/to/output:/output \
  meme-maker \
  --input /input/clip.mp4 \
  --audio /input/song.mp3 \
  --loop-audio
```

### Image + Audio

Create a video from a static image and an audio file. The image is
displayed for the entire duration of the audio (or a custom duration).

```sh
docker run --rm \
  -v /absolute/path/to/inputs:/input:ro \
  -v /absolute/path/to/output:/output \
  meme-maker \
  --input /input/photo.png \
  --audio /input/voiceover.mp3
```

The image format can be PNG, JPEG, BMP, TIFF, or WebP. Duration
defaults to the length of the audio file.

#### Image + Audio with custom duration

```sh
docker run --rm \
  -v /absolute/path/to/inputs:/input:ro \
  -v /absolute/path/to/output:/output \
  meme-maker \
  --input /input/photo.jpg \
  --audio /input/sound.mp3 \
  --duration 15
```

This creates a 15-second video of the static image with the first
15 seconds of the audio.

### Tweet + Audio

Download the embedded video from a Twitter/X post and combine it with
an audio track. Uses `yt-dlp` under the hood.

```sh
docker run --rm \
  -v /absolute/path/to/inputs:/input:ro \
  -v /absolute/path/to/output:/output \
  meme-maker \
  --tweet "https://x.com/user/status/1234567890" \
  --audio /input/song.mp3
```

The `--tweet` flag is mutually exclusive with `--input` — use one or
the other. All other options (`--duration`, `--loop-audio`,
`--top-text`, `--bottom-text`, etc.) work with `--tweet` too.

#### Tweet with original audio, trimmed, and captioned

Download a tweet video, trim to a specific time range, keep the
original audio, and add a caption — all in one command:

```sh
docker run --rm \
  -v /absolute/path/to/output:/output \
  meme-maker \
  --tweet "https://x.com/user/status/1234567890" \
  --start 00:01:27 \
  --end 00:01:47 \
  --top-text "WHEN AGI TAKES OVER"
```

When `--audio` is omitted, the original video audio is preserved.

### Meme captions

Add classic meme-style text (white with black outline) to the top
and/or bottom of the video.

```sh
docker run --rm \
  -v /absolute/path/to/inputs:/input:ro \
  -v /absolute/path/to/output:/output \
  meme-maker \
  --input /input/clip.mp4 \
  --audio /input/song.mp3 \
  --top-text "WHEN THE CODE COMPILES" \
  --bottom-text "ON THE FIRST TRY"
```

You can use just `--top-text`, just `--bottom-text`, or both. The
font size scales automatically with the video resolution. Special
characters (colons, apostrophes, semicolons) are escaped automatically.

### Full example (end to end)

Assuming your files are in `~/meme-files/` and you want the output
in the current directory:

```sh
# Build once
docker build -t meme-maker .

# Video + audio, 30 second meme
docker run --rm \
  -v ~/meme-files:/input:ro \
  -v "$(pwd)/output":/output \
  meme-maker \
  --input /input/funny-clip.mp4 \
  --audio /input/bass-drop.mp3 \
  --duration 30 \
  --output /output/final-meme.mp4

# Image + audio, full audio length
docker run --rm \
  -v ~/meme-files:/input:ro \
  -v "$(pwd)/output":/output \
  meme-maker \
  --input /input/reaction-face.png \
  --audio /input/dramatic-sound.mp3 \
  --output /output/image-meme.mp4
```

Output files appear in `./output/` on your host machine.

### Download Audio from YouTube

Extract audio from a YouTube video and save it as an MP3. This uses
`yt-dlp` which is included in the Docker image.

```sh
docker run --rm \
  -v /absolute/path/to/output:/output \
  --entrypoint /app/download-audio.sh \
  meme-maker \
  --url "https://www.youtube.com/watch?v=VIDEO_ID"
```

The audio file will be saved to `/absolute/path/to/output/audio.mp3`.

#### Custom output filename

```sh
docker run --rm \
  -v /absolute/path/to/output:/output \
  --entrypoint /app/download-audio.sh \
  meme-maker \
  --url "https://www.youtube.com/watch?v=VIDEO_ID" \
  --output /output/my-song.mp3
```

#### Trim to a specific time range

Download audio and extract only a portion using `--start` and `--end`.
Times can be in `HH:MM:SS` format or plain seconds.

```sh
docker run --rm \
  -v /absolute/path/to/output:/output \
  --entrypoint /app/download-audio.sh \
  meme-maker \
  --url "https://www.youtube.com/watch?v=VIDEO_ID" \
  --start 00:01:05 \
  --end 00:01:45
```

This downloads the full audio, then trims it to the 1:05–1:45 range
(40 seconds) and saves the result.

You can also use just `--start` (trim from that point to the end) or
just `--end` (trim from the beginning to that point):

```sh
# First 30 seconds only
docker run --rm \
  -v /absolute/path/to/output:/output \
  --entrypoint /app/download-audio.sh \
  meme-maker \
  --url "https://www.youtube.com/watch?v=VIDEO_ID" \
  --end 30
```

#### Download audio then create a meme (end to end)

```sh
# Download audio from YouTube
docker run --rm \
  -v "$(pwd)/inputs":/output \
  --entrypoint /app/download-audio.sh \
  meme-maker \
  --url "https://www.youtube.com/watch?v=VIDEO_ID" \
  --output /output/song.mp3

# Use the downloaded audio to create a meme
docker run --rm \
  -v "$(pwd)/inputs":/input:ro \
  -v "$(pwd)/output":/output \
  meme-maker \
  --input /input/photo.jpg \
  --audio /input/song.mp3 \
  --duration 15
```

## Options

### make-meme.sh (default entrypoint)

| Flag | Required | Description |
|------|----------|-------------|
| `--input` | Yes* | Path to video or image file (inside the container, e.g. `/input/file.mp4`) |
| `--tweet` | Yes* | URL of a Twitter/X post with an embedded video (alternative to `--input`) |
| `--audio` | No** | Path to audio file. Omit to keep original video audio |
| `--output` | No | Output path (default: `/output/meme.mp4`) |
| `--top-text` | No | Text to display at the top of the video (white with black outline) |
| `--bottom-text` | No | Text to display at the bottom of the video (white with black outline) |
| `--start` | No | Start time for input video trimming (e.g. `00:01:30` or `90`) |
| `--end` | No | End time for input video trimming (e.g. `00:02:15` or `135`) |
| `--duration` | No | Duration in seconds. Defaults to the video length or audio length (for images) |
| `--loop-audio` | No | Loop the audio track if it is shorter than the video |

\* Either `--input` or `--tweet` is required, but not both.
\*\* Required when using a static image as input. Optional for video inputs (omit to keep original audio).

### download-audio.sh (via `--entrypoint`)

| Flag | Required | Description |
|------|----------|-------------|
| `--url` | Yes | YouTube video URL |
| `--output` | No | Output path (default: `/output/audio.mp3`) |
| `--start` | No | Start time for trimming (e.g. `00:01:30` or `90`) |
| `--end` | No | End time for trimming (e.g. `00:02:15` or `135`) |

## Output format

All output is MP4 with:

- **Video**: H.264, yuv420p pixel format, CRF 23
- **Audio**: AAC at 192 kbps
- **`faststart`** flag enabled for quick playback on social media

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
