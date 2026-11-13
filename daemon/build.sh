#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$DIR/.." && pwd)"
OUTPUT="$PROJECT_ROOT/src/Bluesnooze/Resources/bluenap-wifid"

echo "==> Compiling native bluenap-wifid universal daemon..."
TMP_ARM64="/tmp/bluenap-wifid-arm64"
TMP_X86_64="/tmp/bluenap-wifid-x86_64"

swiftc -Osize -target arm64-apple-macos14.0 "$DIR/main.swift" -o "$TMP_ARM64"
swiftc -Osize -target x86_64-apple-macos14.0 "$DIR/main.swift" -o "$TMP_X86_64"
strip -x "$TMP_ARM64" "$TMP_X86_64"

lipo -create -output "$OUTPUT" "$TMP_ARM64" "$TMP_X86_64"
chmod +x "$OUTPUT"
unlink "$TMP_ARM64" || true
unlink "$TMP_X86_64" || true

echo "==> Successfully built universal binary: $OUTPUT"
lipo -info "$OUTPUT"
