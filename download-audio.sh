#!/bin/sh
set -e

print_usage() {
  echo "Usage: download-audio.sh --url <youtube-url> [options]"
  echo ""
  echo "Options:"
  echo "  --url      YouTube video URL (required)"
  echo "  --output   Output file path (default: /output/audio.mp3)"
  echo "  --start    Start time for trimming (e.g. 00:01:30 or 90)"
  echo "  --end      End time for trimming (e.g. 00:02:15 or 135)"
  echo ""
  echo "If --start and/or --end are provided, the audio will be trimmed"
  echo "to that range after downloading. Times can be in HH:MM:SS or seconds."
  exit 1
}

URL=""
OUTPUT="/output/audio.mp3"
START=""
END=""

while [ $# -gt 0 ]; do
  case "$1" in
    --url)    URL="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --start)  START="$2"; shift 2 ;;
    --end)    END="$2"; shift 2 ;;
    --help|-h) print_usage ;;
    *)        echo "Unknown option: $1"; print_usage ;;
  esac
done

if [ -z "$URL" ]; then
  echo "Error: --url is required."
  echo ""
  print_usage
fi

mkdir -p "$(dirname "$OUTPUT")"

echo "=== YouTube Audio Downloader ==="
echo "URL:    $URL"
echo "Output: $OUTPUT"
if [ -n "$START" ]; then echo "Start:  $START"; fi
if [ -n "$END" ];   then echo "End:    $END"; fi
echo ""

# If trimming is requested, download to a temp file first
if [ -n "$START" ] || [ -n "$END" ]; then
  TEMP_FILE="/tmp/yt-audio-full.mp3"

  echo "Downloading full audio..."
  yt-dlp \
    --extract-audio \
    --audio-format mp3 \
    --audio-quality 192K \
    --no-playlist \
    -o "$TEMP_FILE" \
    "$URL"

  echo ""
  echo "Trimming audio..."

  TRIM_ARGS=""
  if [ -n "$START" ]; then
    TRIM_ARGS="$TRIM_ARGS -ss $START"
  fi
  if [ -n "$END" ]; then
    TRIM_ARGS="$TRIM_ARGS -to $END"
  fi

  ffmpeg -y \
    $TRIM_ARGS \
    -i "$TEMP_FILE" \
    -c:a libmp3lame \
    -b:a 192k \
    "$OUTPUT"

  rm -f "$TEMP_FILE"
else
  yt-dlp \
    --extract-audio \
    --audio-format mp3 \
    --audio-quality 192K \
    --no-playlist \
    -o "$OUTPUT" \
    "$URL"
fi

echo ""
echo "Done! Audio saved to: $OUTPUT"
