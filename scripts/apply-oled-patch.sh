#!/usr/bin/env bash
# Enables the SSD1309 OLED driver (2.42" 128x64 SPI OLED mod by DongkwanYi)
# in an EdgeTX source tree (v2.10.0 or newer).
#
# Usage: apply-oled-patch.sh <path-to-edgetx-source>
#
# EdgeTX already contains the SSD1309 driver code (used by e.g. Jumper T14),
# it is just not enabled for the B&W radios that get the OLED mod.
# This script adds two defines right after the "// LCD driver" marker
# in radio/src/targets/taranis/hal.h:
#
#   #define OLED_SCREEN
#   #define SSD1309_LCD
#
# It fails loudly if the source layout has changed, so a broken build is
# never published silently.

set -euo pipefail

SRC="${1:?usage: $0 <edgetx-source-dir>}"
HAL="$SRC/radio/src/targets/taranis/hal.h"
DRV="$SRC/radio/src/targets/taranis/lcd_driver_spi.cpp"
MARK="// OLEDBOXER mod (auto-applied)"

for f in "$HAL" "$DRV"; do
  [[ -f "$f" ]] || { echo "ERROR: missing $f - EdgeTX source layout changed" >&2; exit 1; }
done

if ! grep -q "defined(SSD1309_LCD)" "$DRV"; then
  echo "ERROR: SSD1309 driver code not found in lcd_driver_spi.cpp - patch needs updating" >&2
  exit 1
fi

if grep -qF "$MARK" "$HAL"; then
  echo "Patch already applied."
  exit 0
fi

count=$(grep -c '^// LCD driver[[:space:]]*$' "$HAL" || true)
if [[ "$count" != "1" ]]; then
  echo "ERROR: expected exactly one '// LCD driver' marker in hal.h, found $count - patch needs updating" >&2
  exit 1
fi

awk -v mark="$MARK" '
  { print }
  /^\/\/ LCD driver[[:space:]]*$/ {
    print mark
    print "#define OLED_SCREEN"
    print "#define SSD1309_LCD"
  }
' "$HAL" > "$HAL.tmp" && mv "$HAL.tmp" "$HAL"

# Sanity check: the defines must come before the SPI prescaler selection.
def_line=$(grep -n '^#define SSD1309_LCD$' "$HAL" | head -1 | cut -d: -f1)
pre_line=$(grep -n 'LCD_SPI_PRESCALER[[:space:]]*SPI_CR1_BR_1' "$HAL" | head -1 | cut -d: -f1)
if [[ -z "$pre_line" || "$def_line" -gt "$pre_line" ]]; then
  echo "ERROR: SSD1309 SPI prescaler block not found after the inserted defines" >&2
  exit 1
fi

echo "OLED patch applied to $HAL:"
grep -n -A3 -F "$MARK" "$HAL"

# Radios with a PWM-driven LCD backlight (MT12, T12MAX) define
# LCD_BRIGHTNESS_DEFAULT in board.h, which makes the bootloader call
# backlightEnable() - not declared when OLED_SCREEN is set. An OLED has no
# backlight (brightness = contrast), so drop that define for OLED builds.
BOARD="$SRC/radio/src/targets/taranis/board.h"
if grep -q '#define LCD_BRIGHTNESS_DEFAULT' "$BOARD" && ! grep -qF "$MARK" "$BOARD"; then
  awk -v mark="$MARK" '
    { print }
    /#define LCD_BRIGHTNESS_DEFAULT/ { seen = 1 }
    seen && !done && /^#endif/ {
      print mark
      print "#if defined(OLED_SCREEN)"
      print "  #undef LCD_BRIGHTNESS_DEFAULT"
      print "#endif"
      done = 1
    }
  ' "$BOARD" > "$BOARD.tmp" && mv "$BOARD.tmp" "$BOARD"
  echo "Disabled LCD_BRIGHTNESS_DEFAULT for OLED in $BOARD:"
  grep -n -B6 -A3 -F "$MARK" "$BOARD"
fi
