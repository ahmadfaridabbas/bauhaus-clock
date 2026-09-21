#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash src/build.sh
codesign --verify --strict BauhausHands.saver
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' src/Info.plist)
mkdir -p docs/downloads
ditto -c -k --keepParent --norsrc BauhausHands.saver "docs/downloads/BauhausHands-$VERSION.zip"
shasum -a 256 "docs/downloads/BauhausHands-$VERSION.zip" > docs/downloads/SHA256SUMS.txt
