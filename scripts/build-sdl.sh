#!/bin/sh
# Build a debug SDL3 (same series as Steam's bundled copy) into build/, for
# tracing the HIDAPI/libusb/GIP path. libusb and udev dev headers are unpacked
# from Debian .debs into build/sysroot so no root is needed; SDL dlopens the
# real libraries at runtime.
#
# Usage: scripts/build-sdl.sh [sdl-git-ref]   (default main; Steam ships a main snapshot)
set -eu
REF=${1:-main}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
B=$ROOT/build
mkdir -p "$B/debs" "$B/sysroot"

cd "$B/debs"
if [ ! -f .done ]; then
    apt-get download libusb-1.0-0-dev libudev-dev
    for d in *.deb; do dpkg-deb -x "$d" "$B/sysroot"; done
    touch .done
fi

if [ ! -d "$B/SDL" ]; then
    git clone --depth 1 --branch "$REF" https://github.com/libsdl-org/SDL.git "$B/SDL"
fi

INC=$B/sysroot/usr/include
# Dev .so symlinks the linker wants, pointing at the installed runtime libs.
mkdir -p "$B/libs"
ln -sf /usr/lib/x86_64-linux-gnu/libudev.so.1 "$B/libs/libudev.so"
cmake -S "$B/SDL" -B "$B/sdl-build" -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_C_FLAGS="-I$INC -I$INC/libusb-1.0 -DDEBUG_HIDAPI -DDEBUG_XBOX_PROTOCOL" \
    -DSDL_HIDAPI_LIBUSB=ON -DSDL_HIDAPI_LIBUSB_SHARED=ON \
    -DLibUSB_INCLUDE_PATH="$INC/libusb-1.0" \
    -DLibUSB_LIBRARY=/usr/lib/x86_64-linux-gnu/libusb-1.0.so.0 \
    -DSDL_UNIX_CONSOLE_BUILD=ON \
    -DCMAKE_SHARED_LINKER_FLAGS="-L$B/libs" \
    -DSDL_TESTS=OFF -DSDL_VIDEO=OFF -DSDL_AUDIO=OFF -DSDL_RENDER=OFF -DSDL_GPU=OFF -DSDL_CAMERA=OFF
cmake --build "$B/sdl-build"
echo "built: $B/sdl-build/libSDL3.so.0"
