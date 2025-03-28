#!/bin/bash

## Read input options.
#OPTS=$(getopt -o o::s:p::r:: --long output::,sender-ip:,port::,resolution:: -- "$@" )
#
#if [ $? -ne 0 ]
#then
#    echo "Failed to parse options." >&2
#    exit 1
#fi
#
#eval set -- "$OPTS"
#
## extract options and their arguments into variables.
#while true ; do
#    case "$1" in
#        -o|--output)
#          case "$2" in
#            "") 
#              OUTPUT_PATH='/tmp'
#              shift 2
#              ;;
#            *) 
#              OUTPUT_PATH=$2
#              shift 2
#              ;;
#          esac
#          ;;
#        -s|--sender-ip)
#            SENDER_IP=$2
#            shift 2
#            ;;
#        -p|--port)
#          case "$2" in
#            "")
#              SENDER_PORT='5000'
#              shift 2
#              ;;
#            *)
#              SENDER_PORT=$2
#              shift 2
#              ;;
#          esac
#          ;;
#        -r|--resolution)
#          case "$2" in
#            "") 
#              RESOLUTION='1080'
#              shift 2
#              ;;
#            *)
#              RESOLUTION=$2
#              shift 2
#              ;;
#          esac
#          ;;
#        --) 
#          shift
#          break
#          ;;
#        *) 
#          echo "Unrecognized flag." 
#          exit
#          ;;
#    esac
#done
#
#echo "Remaining arguments:"
#for arg in "$@"
#do
#  echo "--> '$arg'"
#done

# Report start.
echo "`date`: ********* START $0 STREAM CAPTURE SETUP *********"

# TEMP: replace with input args.
SENDER=35.225.145.79:5000
RESOLUTION=1080
OUTPUT_PATH=/tmp/test

# Details: receive RTP stream from truck then write
# 3.2s chunks directly to disk.

OUTPUT_DIR=$(dirname $OUTPUT_PATH)
OUTPUT_BASE="streamChunk"
mkdir -p $OUTPUT_DIR

# Set up file naming vars.
# For OUTPUT_PAD, use double-% to accommodate second_level_segment_index.
STRFTIME="%Y%m%dt%H%M%S"
OUTPUT_PAD="%%06d" 
OUTPUT_EXT="ts"
PLAYLIST_EXT="m3u8"

# Construct source.
SRT_SOURCE="srt://${SENDER}?pkt_size=1316&mode=caller&nakreport=1"

# Query which AVX are present on the chip. If compatible with avx512, us that.
lscpu | grep -q avx512
[[ $? = 0 ]] && _ASM="avx512" || _ASM="avx2"

# Report ffmpeg start.
echo "`date`: ********* START $0 STREAM CAPTURE *********"

# Construct ffmpeg and args.
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
  -hls_segment_filename "$OUTPUT_DIR/$OUTPUT_BASE-$STRFTIME-$OUTPUT_PAD.$OUTPUT_EXT" \
  $OUTPUT_DIR/$OUTPUT_BASE.$PLAYLIST_EXT

# Report end.
echo "`date`: ********* END $0 STREAM CAPTURE *********"