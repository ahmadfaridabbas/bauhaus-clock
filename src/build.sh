#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
DEST="../BauhausHands.saver"
mkdir -p "$DEST/Contents/MacOS"
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter -arch arm64 -arch x86_64 -mmacosx-version-min=15.5 -bundle BauhausHandsView.m -framework ScreenSaver -framework Cocoa -framework QuartzCore -framework CoreText -o "$DEST/Contents/MacOS/BauhausHands"
cp Info.plist "$DEST/Contents/Info.plist"
codesign --force --sign - "$DEST"
