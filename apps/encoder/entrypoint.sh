#!/bin/bash

# Details: receive RTP stream from truck then write
# 3.2s chunks directly to disk.

# Construct source.
SRT_SOURCE="srt://${SENDER_ADDR}?pkt_size=1316&mode=caller&nakreport=1"

# Define ASM
lscpu | grep -q avx512
[[ $? = 0 ]] && _ASM="avx512" || _ASM="avx2"

ffmpeg \
  -i $SRT_SOURCE \
  -loglevel info \
  -y \
  -c:v libx264 \
  -filter:v scale="-2:$RESOLUTION" \
  -preset:v medium \
  -x264-params "keyint=120:min-keyint=120:sliced-threads=0:scenecut=0:asm=${_ASM}" \
  -tune psnr -profile:v high -b:v 6M -maxrate 12M -bufsize 24M \
  -c:a copy \
  -reset_timestamps 1 \
  -sc_threshold 0 \
  -force_key_frames "expr:gte(t, n_forced * 3.2)" \
  -strftime 1 \
  -hls_time "3.2" \
  -hls_list_size 0 \
  -hls_playlist_type event \
  -hls_flags second_level_segment_index \
  -f hls \
  -hls_playlist 0 \
  -hls_segment_filename "${OUTPUT_PATH}/${OUTPUT_BASE}_${STRFTIME}_${OUTPUT_PAD}.${OUTPUT_EXT}" \
  $OUTPUT_DIR/$OUTPUT_BASE.$PLAYLIST_EXT
