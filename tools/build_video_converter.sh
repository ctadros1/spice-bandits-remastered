#!/bin/zsh
# Build-only dependency. The macOS app uses Godot's built-in Theora decoder.
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_build="$task_root/work/toolchain/ffmpeg-build"
mkdir -p "$task_build"
archive="$task_build/ffmpeg-8.1.3.tar.xz"
expected='7138d28c96d9d3e3af4ee3d8cad72741f8ffb40da90c1112235dea3ecd3178a3'
if [[ ! -f "$archive" ]]; then
  curl -fL --max-time 180 https://ffmpeg.org/releases/ffmpeg-8.1.3.tar.xz -o "$archive.part"
  [[ "$(shasum -a 256 "$archive.part" | cut -d ' ' -f 1)" == "$expected" ]] || { print 'FFmpeg source hash mismatch.'; exit 1; }
  mv "$archive.part" "$archive"
fi
[[ "$(shasum -a 256 "$archive" | cut -d ' ' -f 1)" == "$expected" ]] || { print 'FFmpeg source hash mismatch.'; exit 1; }
[[ "$(pkg-config --modversion theoraenc)" == '1.2.0' && "$(pkg-config --modversion vorbisenc)" == '1.3.7' && "$(pkg-config --modversion ogg)" == '1.3.6' ]] || { print 'See docs/BUILD.md for the pinned video encoder libraries.'; exit 1; }
if [[ ! -d "$task_build/ffmpeg-8.1.3" ]]; then tar -xf "$archive" -C "$task_build"; fi
cd "$task_build/ffmpeg-8.1.3"
./configure --prefix="$task_build/runtime" \
  --extra-cflags="$(pkg-config --cflags theoraenc vorbisenc ogg)" \
  --extra-ldflags="$(pkg-config --libs-only-L theoraenc vorbisenc ogg)" \
  --disable-everything --disable-programs --enable-ffmpeg \
  --enable-libtheora --enable-libvorbis \
  --enable-decoder=h264,mp3,mp3float,pcm_s16le,rawvideo \
  --enable-parser=h264,mpegaudio --enable-demuxer=mov,avi,wav,yuv4mpegpipe \
  --enable-muxer=ogg --enable-encoder=libtheora,libvorbis \
  --enable-filter=scale,format,aresample,aformat,anull,null \
  --enable-protocol=file,pipe --disable-doc > "$task_build/configure.log" 2>&1
make -j8 > "$task_build/compile.log" 2>&1
./ffmpeg -version | head -n 1
