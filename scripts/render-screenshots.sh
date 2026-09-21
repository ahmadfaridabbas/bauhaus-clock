#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
RENDER_TEMP=$(mktemp -d)
trap 'rm -rf "$RENDER_TEMP"' EXIT
python3 - "$RENDER_TEMP" <<'PY'
from pathlib import Path
import sys
source = Path('src/BauhausHandsView.m').read_text()
needle = 'NSDate *date = [NSDate date];'
assert source.count(needle) >= 1
replacement = '''NSDateComponents *fixed = [[NSDateComponents alloc] init];
    fixed.year=2026; fixed.month=9; fixed.day=21; fixed.hour=10; fixed.minute=10; fixed.second=35;
    NSDate *date = [[NSCalendar currentCalendar] dateFromComponents:fixed];'''
Path(sys.argv[1], 'ScreenshotClock.m').write_text(source.replace(needle, replacement, 1))
PY
xcrun clang -fobjc-arc -O2 -I "$RENDER_TEMP" -I src scripts/render-screenshots.m -framework ScreenSaver -framework Cocoa -framework QuartzCore -framework CoreText -o "$RENDER_TEMP/render"
"$RENDER_TEMP/render"
