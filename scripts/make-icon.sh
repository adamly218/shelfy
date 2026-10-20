#!/bin/zsh
# Regenerates Resources/AppIcon.icns from scripts/make-icon.swift. Run: ./scripts/make-icon.sh
set -e
cd "${0:A:h}/.."

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
xcrun swiftc -O scripts/make-icon.swift -o "$WORK/make-icon"
"$WORK/make-icon" "$WORK/icon.png"

ICONSET="$WORK/AppIcon.iconset"
mkdir "$ICONSET"
for px in 16 32 128 256 512; do
  sips -z $px $px "$WORK/icon.png" --out "$ICONSET/icon_${px}x${px}.png" >/dev/null
  sips -z $((px * 2)) $((px * 2)) "$WORK/icon.png" --out "$ICONSET/icon_${px}x${px}@2x.png" >/dev/null
done
mkdir -p Resources
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
cp "$WORK/icon.png" docs/icon.png
echo "Resources/AppIcon.icns"
