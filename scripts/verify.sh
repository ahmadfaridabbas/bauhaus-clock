#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_TEMP=$(mktemp -d)
trap 'rm -rf "$TEST_TEMP"' EXIT
xcrun clang -fobjc-arc -Wno-unused-parameter tests/verify.m -framework ScreenSaver -framework Cocoa -framework QuartzCore -framework CoreText -o "$TEST_TEMP/verify"
"$TEST_TEMP/verify"
