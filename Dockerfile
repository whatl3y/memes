FROM alpine:3.19

RUN apk add --no-cache ffmpeg python3 py3-pip && \
    pip3 install --no-cache-dir --break-system-packages yt-dlp

WORKDIR /app

COPY make-meme.sh download-audio.sh ./
RUN chmod +x make-meme.sh download-audio.sh

# Input files get mounted to /input, output goes to /output
RUN mkdir -p /input /output

ENTRYPOINT ["/app/make-meme.sh"]
