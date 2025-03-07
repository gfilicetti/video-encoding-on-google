# FROM intel/intel-optimized-ffmpeg:avx2
FROM debian:latest

ENV RESOLUTION=1080
ENV OUTPATH=/output
ENV FILENAME=outputfile_%06d.mp4

RUN apt-get update \
    && apt-get install -y --no-install-recommends util-linux curl mediainfo ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY ./entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/bin/sh", "-c", "/entrypoint.sh"]
