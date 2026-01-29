#!/bin/sh
set -e

print_usage() {
  echo "Usage: make-meme.sh [options] --input <video|image> --audio <audio> [--output <path>]"
  echo ""
  echo "Options:"
  echo "  --input        Path to a video or image file (required)"
  echo "  --audio        Path to an audio file (required)"
  echo "  --output       Output file path (default: /output/meme.mp4)"
  echo "  --duration     Duration in seconds (trims or sets video length)"
  echo "  --loop-audio   Loop the audio if shorter than the video"
  echo ""
  echo "Modes:"
  echo "  Video + Audio   Provide a video file as --input to merge with audio"
  echo "  Image + Audio   Provide a static image as --input to create a video"
  exit 1
}

INPUT=""
AUDIO=""
OUTPUT="/output/meme.mp4"
DURATION=""
LOOP_AUDIO=""

while [ $# -gt 0 ]; do
  case "$1" in
    --input)      INPUT="$2"; shift 2 ;;
    --audio)      AUDIO="$2"; shift 2 ;;
    --output)     OUTPUT="$2"; shift 2 ;;
    --duration)   DURATION="$2"; shift 2 ;;
    --loop-audio) LOOP_AUDIO=1; shift ;;
    --help|-h)    print_usage ;;
    *)            echo "Unknown option: $1"; print_usage ;;
  esac
done

if [ -z "$INPUT" ] || [ -z "$AUDIO" ]; then
  echo "Error: --input and --audio are required."
  echo ""
  print_usage
fi

# Detect whether the input is an image or video based on ffprobe
INPUT_TYPE=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_type,codec_name,nb_read_frames -count_frames -of csv=p=0 "$INPUT" 2>/dev/null | head -1)
CODEC_NAME=$(echo "$INPUT_TYPE" | cut -d',' -f1)

# Image codecs that indicate a still image
is_image() {
  case "$CODEC_NAME" in
    png|mjpeg|bmp|tiff|webp) return 0 ;;
    *) return 1 ;;
  esac
}

# Also check if the input has zero or one frame (single image)
FRAME_COUNT=$(ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of csv=p=0 "$INPUT" 2>/dev/null || echo "0")

mkdir -p "$(dirname "$OUTPUT")"

echo "=== Meme Generator ==="
echo "Input:  $INPUT"
echo "Audio:  $AUDIO"
echo "Output: $OUTPUT"

if is_image || [ "$FRAME_COUNT" = "1" ]; then
  # --- Static Image + Audio mode ---
  echo "Mode:   Image + Audio → Video"

  if [ -z "$DURATION" ]; then
    # Default to audio duration when no --duration specified
    DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$AUDIO")
    echo "Duration: ${DURATION}s (from audio)"
  else
    echo "Duration: ${DURATION}s (user-specified)"
  fi

  LOOP_FLAG=""
  if [ -n "$LOOP_AUDIO" ]; then
    LOOP_FLAG="-stream_loop -1"
  fi

  ffmpeg -y \
    -loop 1 -framerate 30 -i "$INPUT" \
    $LOOP_FLAG -i "$AUDIO" \
    -map 0:v:0 \
    -map 1:a:0 \
    -c:v libx264 \
    -preset medium \
    -crf 23 \
    -c:a aac \
    -b:a 192k \
    -t "$DURATION" \
    -movflags +faststart \
    -pix_fmt yuv420p \
    -shortest \
    "$OUTPUT"

else
  # --- Video + Audio mode ---
  echo "Mode:   Video + Audio → Video"

  if [ -z "$DURATION" ]; then
    DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$INPUT")
    echo "Duration: ${DURATION}s (from video)"
  else
    echo "Duration: ${DURATION}s (user-specified)"
  fi

  LOOP_FLAG=""
  if [ -n "$LOOP_AUDIO" ]; then
    LOOP_FLAG="-stream_loop -1"
  fi

  # Loop the video input so it repeats to fill the full duration
  VIDEO_DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$INPUT")
  LOOP_VIDEO=""
  if [ -n "$VIDEO_DURATION" ] && [ "$VIDEO_DURATION" != "N/A" ]; then
    NEEDS_LOOP=$(awk "BEGIN { print ($DURATION > $VIDEO_DURATION) ? 1 : 0 }")
    if [ "$NEEDS_LOOP" = "1" ]; then
      LOOP_VIDEO="-stream_loop -1"
      echo "Looping video to fill ${DURATION}s (video is ${VIDEO_DURATION}s)"
    fi
  fi

  ffmpeg -y \
    $LOOP_VIDEO -i "$INPUT" \
    $LOOP_FLAG -i "$AUDIO" \
    -map 0:v:0 \
    -map 1:a:0 \
    -c:v libx264 \
    -preset medium \
    -crf 23 \
    -c:a aac \
    -b:a 192k \
    -t "$DURATION" \
    -movflags +faststart \
    -pix_fmt yuv420p \
    -shortest \
    "$OUTPUT"
fi

echo ""
echo "Done! Meme saved to: $OUTPUT"
