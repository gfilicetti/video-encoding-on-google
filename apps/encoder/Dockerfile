# FROM intel/intel-optimized-ffmpeg:avx2
FROM debian:latest

ENV OUTPUT_PATH="/output"
ENV OUTPUT_BASE="ffmpeg-test"
ENV OUTPUT_PAD="%06d"
ENV OUTPUT_EXT="ts"
ENV SEGMENT_TIME="3.2"

# Vertical resolution of output.
ENV RESOLUTION=1080

RUN apt-get update \
    && apt-get install -y --no-install-recommends util-linux curl mediainfo ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY ./entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/bin/sh", "-c", "/entrypoint.sh"]
