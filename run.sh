#!/bin/sh
set -e

IMAGE_NAME="meme-maker"

# Parse arguments
VIDEO=""
AUDIO=""
OUTPUT=""
EXTRA_ARGS=""

print_usage() {
  echo "Usage: ./run.sh --video <path> --audio <path> [--output <path>] [--loop-audio]"
  echo ""
  echo "Options:"
  echo "  --video       Path to the video file (required)"
  echo "  --audio       Path to the audio file (required)"
  echo "  --output      Path for the output file (default: ./output/meme.mp4)"
  echo "  --loop-audio  Loop the audio if it's shorter than the video"
  echo ""
  echo "Examples:"
  echo "  ./run.sh --video clip.mp4 --audio song.mp3"
  echo "  ./run.sh --video clip.mp4 --audio song.mp3 --output my-meme.mp4"
  echo "  ./run.sh --video clip.mp4 --audio song.mp3 --loop-audio"
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --video)  VIDEO="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"; shift 2 ;;
    --audio)  AUDIO="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"; shift 2 ;;
    --output) OUTPUT="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"; shift 2 ;;
    --loop-audio) EXTRA_ARGS="--loop-audio"; shift ;;
    --help|-h) print_usage ;;
    *) echo "Unknown option: $1"; print_usage ;;
  esac
done

if [ -z "$VIDEO" ] || [ -z "$AUDIO" ]; then
  echo "Error: --video and --audio are required."
  echo ""
  print_usage
fi

# Default output
if [ -z "$OUTPUT" ]; then
  OUTPUT="$(pwd)/output/meme.mp4"
fi

OUTPUT_DIR="$(dirname "$OUTPUT")"
OUTPUT_FILE="$(basename "$OUTPUT")"
mkdir -p "$OUTPUT_DIR"

# Build the Docker image if it doesn't exist
echo "Building Docker image..."
docker build -t "$IMAGE_NAME" "$(dirname "$0")"

echo ""
echo "Running meme generator..."
docker run --rm \
  -v "$(dirname "$VIDEO"):/input/video:ro" \
  -v "$(dirname "$AUDIO"):/input/audio:ro" \
  -v "$OUTPUT_DIR:/output" \
  "$IMAGE_NAME" \
  "/input/video/$(basename "$VIDEO")" \
  "/input/audio/$(basename "$AUDIO")" \
  "/output/$OUTPUT_FILE" \
  $EXTRA_ARGS
