#!/bin/sh
set -e

print_usage() {
  echo "Usage: make-meme.sh [options] --input <video|image> --audio <audio> [--output <path>]"
  echo ""
  echo "Options:"
  echo "  --input        Path to a video or image file (required unless --tweet is used)"
  echo "  --tweet        URL of a tweet/X post with an embedded video (used as --input)"
  echo "  --audio        Path to an audio file (omit to keep original video audio)"
  echo "  --output       Output file path (default: /output/meme.mp4)"
  echo "  --top-text     Text to display at the top of the video"
  echo "  --bottom-text  Text to display at the bottom of the video"
  echo "  --start        Start time for input video (e.g. 00:01:30 or 90)"
  echo "  --end          End time for input video (e.g. 00:02:15 or 135)"
  echo "  --duration     Duration in seconds (trims or sets video length)"
  echo "  --loop-audio   Loop the audio if shorter than the video"
  echo ""
  echo "Modes:"
  echo "  Video + Audio   Provide a video file as --input to merge with audio"
  echo "  Image + Audio   Provide a static image as --input to create a video"
  echo "  Tweet + Audio   Provide a tweet URL as --tweet to download and use its video"
  exit 1
}

INPUT=""
AUDIO=""
OUTPUT="/output/meme.mp4"
DURATION=""
LOOP_AUDIO=""
TWEET=""
TWEET_TEMP=""
TOP_TEXT=""
BOTTOM_TEXT=""
START=""
END=""
TRIMMED_TEMP=""

while [ $# -gt 0 ]; do
  case "$1" in
    --input)       INPUT="$2"; shift 2 ;;
    --tweet)       TWEET="$2"; shift 2 ;;
    --audio)       AUDIO="$2"; shift 2 ;;
    --output)      OUTPUT="$2"; shift 2 ;;
    --top-text)    TOP_TEXT="$2"; shift 2 ;;
    --bottom-text) BOTTOM_TEXT="$2"; shift 2 ;;
    --start)       START="$2"; shift 2 ;;
    --end)         END="$2"; shift 2 ;;
    --duration)    DURATION="$2"; shift 2 ;;
    --loop-audio)  LOOP_AUDIO=1; shift ;;
    --help|-h)     print_usage ;;
    *)             echo "Unknown option: $1"; print_usage ;;
  esac
done

# Download video from tweet URL if --tweet is provided
if [ -n "$TWEET" ]; then
  if [ -n "$INPUT" ]; then
    echo "Error: --input and --tweet are mutually exclusive. Use one or the other."
    exit 1
  fi
  TWEET_TEMP="/tmp/tweet-video.mp4"
  echo "Downloading video from tweet: $TWEET"
  yt-dlp \
    --no-playlist \
    -f "best[ext=mp4]/best" \
    -o "$TWEET_TEMP" \
    "$TWEET"
  INPUT="$TWEET_TEMP"
  echo ""
fi

if [ -z "$INPUT" ]; then
  echo "Error: --input (or --tweet) is required."
  echo ""
  print_usage
fi

# Trim the input video to a time range if --start/--end are provided
if [ -n "$START" ] || [ -n "$END" ]; then
  TRIMMED_TEMP="/tmp/trimmed-input.mp4"
  echo "Trimming input video..."
  TRIM_ARGS=""
  if [ -n "$START" ]; then
    TRIM_ARGS="$TRIM_ARGS -ss $START"
    echo "  Start: $START"
  fi
  if [ -n "$END" ]; then
    TRIM_ARGS="$TRIM_ARGS -to $END"
    echo "  End:   $END"
  fi
  ffmpeg -y $TRIM_ARGS -i "$INPUT" -c copy "$TRIMMED_TEMP"
  # Clean up tweet temp now if applicable
  if [ -n "$TWEET_TEMP" ]; then
    rm -f "$TWEET_TEMP"
    TWEET_TEMP=""
  fi
  INPUT="$TRIMMED_TEMP"
  echo ""
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

# Escape text for ffmpeg drawtext filter (escape \, ', :, ;)
escape_drawtext() {
  printf '%s' "$1" | sed "s/\\\\/\\\\\\\\/g; s/'/\\\\'/g; s/:/\\\\:/g; s/;/\\\\;/g"
}

# Build video filter for meme captions and write to a filter script file.
# Using a file avoids shell word-splitting issues with spaces in text.
# Font size auto-scales: min(h/10, w*0.9/nchars*1.6) so text always fits.
FONT="/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"
VF_FILTER=""
FILTER_SCRIPT=""
if [ -n "$TOP_TEXT" ]; then
  ESCAPED_TOP=$(escape_drawtext "$TOP_TEXT")
  TOP_LEN=$(printf '%s' "$TOP_TEXT" | wc -c | tr -d ' ')
  VF_FILTER="drawtext=text='${ESCAPED_TOP}':fontfile=${FONT}:fontsize='min(h/10\,w*0.9/${TOP_LEN}*1.6)':fontcolor=white:borderw=4:bordercolor=black:x=(w-text_w)/2:y=h*0.05"
fi
if [ -n "$BOTTOM_TEXT" ]; then
  ESCAPED_BOTTOM=$(escape_drawtext "$BOTTOM_TEXT")
  BOT_LEN=$(printf '%s' "$BOTTOM_TEXT" | wc -c | tr -d ' ')
  BOTTOM_FILTER="drawtext=text='${ESCAPED_BOTTOM}':fontfile=${FONT}:fontsize='min(h/10\,w*0.9/${BOT_LEN}*1.6)':fontcolor=white:borderw=4:bordercolor=black:x=(w-text_w)/2:y=h*0.88-text_h"
  if [ -n "$VF_FILTER" ]; then
    VF_FILTER="${VF_FILTER},${BOTTOM_FILTER}"
  else
    VF_FILTER="$BOTTOM_FILTER"
  fi
fi
if [ -n "$VF_FILTER" ]; then
  FILTER_SCRIPT="/tmp/meme-filter.txt"
  printf '%s' "$VF_FILTER" > "$FILTER_SCRIPT"
fi

echo "=== Meme Generator ==="
echo "Input:  $INPUT"
if [ -n "$AUDIO" ]; then
  echo "Audio:  $AUDIO"
else
  echo "Audio:  (original video audio)"
fi
echo "Output: $OUTPUT"
if [ -n "$TOP_TEXT" ];    then echo "Top:    $TOP_TEXT"; fi
if [ -n "$BOTTOM_TEXT" ]; then echo "Bottom: $BOTTOM_TEXT"; fi

if is_image || [ "$FRAME_COUNT" = "1" ]; then
  # --- Static Image + Audio mode ---
  if [ -z "$AUDIO" ]; then
    echo "Error: --audio is required when using a static image as input."
    exit 1
  fi
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

  if [ -n "$FILTER_SCRIPT" ]; then
    ffmpeg -y \
      -loop 1 -framerate 30 -i "$INPUT" \
      $LOOP_FLAG -i "$AUDIO" \
      -map 0:v:0 \
      -map 1:a:0 \
      -filter_script:v "$FILTER_SCRIPT" \
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
  fi

else
  # --- Video mode ---
  if [ -n "$AUDIO" ]; then
    echo "Mode:   Video + Audio → Video"
  else
    echo "Mode:   Video (original audio) → Video"
  fi

  if [ -z "$DURATION" ]; then
    DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$INPUT")
    echo "Duration: ${DURATION}s (from video)"
  else
    echo "Duration: ${DURATION}s (user-specified)"
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

  if [ -n "$AUDIO" ]; then
    # Replace video audio with separate audio file
    LOOP_FLAG=""
    if [ -n "$LOOP_AUDIO" ]; then
      LOOP_FLAG="-stream_loop -1"
    fi

    if [ -n "$FILTER_SCRIPT" ]; then
      ffmpeg -y \
        $LOOP_VIDEO -i "$INPUT" \
        $LOOP_FLAG -i "$AUDIO" \
        -map 0:v:0 \
        -map 1:a:0 \
        -filter_script:v "$FILTER_SCRIPT" \
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
  else
    # Keep original video audio
    if [ -n "$FILTER_SCRIPT" ]; then
      ffmpeg -y \
        $LOOP_VIDEO -i "$INPUT" \
        -map 0:v:0 \
        -map 0:a:0 \
        -filter_script:v "$FILTER_SCRIPT" \
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
      ffmpeg -y \
        $LOOP_VIDEO -i "$INPUT" \
        -map 0:v:0 \
        -map 0:a:0 \
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
  fi
fi

# Clean up temporary files
if [ -n "$TWEET_TEMP" ]; then
  rm -f "$TWEET_TEMP"
fi
if [ -n "$TRIMMED_TEMP" ]; then
  rm -f "$TRIMMED_TEMP"
fi
if [ -n "$FILTER_SCRIPT" ]; then
  rm -f "$FILTER_SCRIPT"
fi

echo ""
echo "Done! Meme saved to: $OUTPUT"
