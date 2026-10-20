#!/bin/zsh
# Builds Shelfy.app next to this script. Run: ./build.sh
set -e
cd "${0:A:h}"

APP=Shelfy.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

# Universal binary: Apple silicon + Intel.
for arch in arm64 x86_64; do
  xcrun swiftc -O -swift-version 5 \
    -target $arch-apple-macos13.0 \
    Sources/*.swift \
    -o "$APP/Contents/MacOS/Shelfy-$arch"
done
lipo -create "$APP"/Contents/MacOS/Shelfy-* -output "$APP/Contents/MacOS/Shelfy"
rm "$APP"/Contents/MacOS/Shelfy-*

codesign --force --sign - "$APP"
echo "Built $PWD/$APP"
