#!/bin/bash -x

# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Report start.
echo "`date`: ********* START $0 SRT CAMERA SETUP *********"

# Install ffmpeg.
echo "`date`: ********* INSTALLING FFMPEG *********"

apt update
apt install -y ffmpeg
apt install -y \
  libaom-dev \
  libass-dev \
  libfdk-aac-dev \
  libnuma-dev \
  libopus-dev \
  libvorbis-dev \
  libvpx-dev \
  libx264-dev \
  libx265-dev \
  nasm \
  unzip

# Query Project metadata for Gateway IP and port.
GATEWAY_IP=$(curl -sX GET http://metadata.google.internal/computeMetadata/v1/project/attributes/gateway_ip -H 'Metadata-Flavor: Google')
CAMERA_PORT=$(curl -sX GET http://metadata.google.internal/computeMetadata/v1/project/attributes/camera_port -H 'Metadata-Flavor: Google')

# Define SRT source.
SRT_SOURCE="srt://${GATEWAY_IP}:${CAMERA_PORT}?pkt_size=1316"

# Software-specific variables.
VIDEO_LOC=https://download.blender.org/demo/movies/BBB
VIDEO_FILE=bbb_sunflower_1080p_30fps_normal.mp4
TMPDIR=/tmp

echo "`date`: ********* DOWNLOADING $VIDEO_FILE *********"

# Download video file
curl -o $TMPDIR/${VIDEO_FILE}.zip ${VIDEO_LOC}/${VIDEO_FILE}.zip 
unzip -o -d $TMPDIR $TMPDIR/${VIDEO_FILE}.zip

echo "`date`: ********* STARTING SRT STREAM *********"

ffmpeg \
  -stream_loop -1 \
  -re \
  -i $TMPDIR/$VIDEO_FILE \
  -c copy \
  -f mpegts $SRT_SOURCE

# Report end.
echo "`date`: ********* END $0 SRT CAMERA *********"
