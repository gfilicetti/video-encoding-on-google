# Specify the source. Because the caller is transmitting to port 5000 of
# the receiver, you specify any IP address on the receiver with an IP of 0.0.0.0.
SRT_SOURCE="srt://0.0.0.0:5000?pkt_size=1316&mode=listener&nakreport=1&listen_timeout=-1"

# Vertical resolution of output.
#RESOLUTION=1080

# Define ASM
lscpu | grep -q avx512
test $? = 0 && _ASM="avx512" || _ASM="avx2"

# These encoding settings are WBD-specific.
# Note: it would be preferred to use a variable, rather than '3.2' throughout,
# however it seems you cannot use an environment variable in an expression.
ffmpeg \
  -re \
  -i ${SRT_SOURCE} \
  -y \
  -map 0 \
  -report \
  -c:v libx264 \
  -filter:v scale="-2:${RESOLUTION}" \
  -preset:v medium \
  -x264-params "keyint=120:min-keyint=120:sliced-threads=0:scenecut=0:asm=${_ASM}" \
  -tune psnr -profile:v high -b:v 6M -maxrate 12M -bufsize 24M \
  -c:a copy \
  -reset_timestamps 1 \
  -sc_threshold 0 \
  -force_key_frames "expr:gte(t, n_forced * 3.2)" \
  -segment_time "3.2" \
  -f segment \
  ${OUTPATH}/${FILENAME}
