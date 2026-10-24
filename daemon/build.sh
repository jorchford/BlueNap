#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$DIR/.." && pwd)"
OUTPUT="$PROJECT_ROOT/src/Bluesnooze/Resources/bluenap-wifid"

echo "==> Compiling native bluenap-wifid universal daemon..."
TMP_ARM64="/tmp/bluenap-wifid-arm64"
TMP_X86_64="/tmp/bluenap-wifid-x86_64"

swiftc -O -target arm64-apple-macos14.0 "$DIR/main.swift" -o "$TMP_ARM64"
swiftc -O -target x86_64-apple-macos14.0 "$DIR/main.swift" -o "$TMP_X86_64"

lipo -create -output "$OUTPUT" "$TMP_ARM64" "$TMP_X86_64"
chmod +x "$OUTPUT"
rm -f "$TMP_ARM64" "$TMP_X86_64"

echo "==> Successfully built universal binary: $OUTPUT"
lipo -info "$OUTPUT"
