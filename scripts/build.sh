#!/usr/bin/env bash
# Builds OLED firmware + bootloader for one radio.
# Runs inside the ghcr.io/edgetx/edgetx-dev container, from the EdgeTX
# source root (already patched with apply-oled-patch.sh).
#
# Env:
#   TARGET      boxer | tx12 | tx12mk2 | zorro | pocket | mt12 | t12max
#   VERSION     e.g. 2.12.5 (used for file names only)
#   STICK_MODE  default stick mode baked in (1-4, default 2)
#   OUT_DIR     where to put the .bin files

set -euo pipefail

: "${TARGET:?}" "${VERSION:?}" "${OUT_DIR:?}"
STICK_MODE="${STICK_MODE:-2}"

case "$TARGET" in
  boxer|tx12|tx12mk2|zorro|pocket|mt12|t12max) ;;
  *) echo "ERROR: unsupported target $TARGET" >&2; exit 1 ;;
esac
PCBREV=$(echo "$TARGET" | tr '[:lower:]' '[:upper:]')

git config --global --add safe.directory "$(pwd)" || true

rm -rf build && mkdir build && cd build
cmake -Wno-dev \
  -DPCB=X7 -DPCBREV="$PCBREV" \
  -DDEFAULT_MODE="$STICK_MODE" \
  -DGVARS=YES \
  -DCMAKE_BUILD_TYPE=Release \
  ..
make configure
make -j"$(nproc)" firmware

NAME=$(echo "OLED${PCBREV}" )
mkdir -p "$OUT_DIR"
cp arm-none-eabi/firmware.bin   "$OUT_DIR/${NAME}-${VERSION}.bin"
cp arm-none-eabi/bootloader.bin "$OUT_DIR/${NAME}-${VERSION}-bootloader.bin"
ls -l "$OUT_DIR"
