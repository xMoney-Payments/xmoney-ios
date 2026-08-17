#!/bin/sh
# Run package tests on an available iPhone simulator. Never macOS —
# XMoneyCore imports UIKit and the package is iOS-only.
set -eu

SCHEME="${1:-XMoneyPaymentSheet-Package}"

DEST_LINE=$(xcodebuild -scheme "$SCHEME" -showdestinations 2>&1 | awk '
  /platform:iOS Simulator/ && /name:iPhone/ && !/Unavailable/ && !/placeholder/ {
    line = $0
  }
  END { print line }
')

if [ -z "$DEST_LINE" ]; then
  echo "No iOS Simulator destination found for $SCHEME:"
  xcodebuild -scheme "$SCHEME" -showdestinations
  exit 1
fi

ID=$(printf '%s\n' "$DEST_LINE" | sed -n 's/.*id:\([^,}]*\).*/\1/p' | tr -d ' ')
if [ -z "$ID" ]; then
  echo "Could not parse simulator id from: $DEST_LINE"
  exit 1
fi

echo "Testing on $DEST_LINE"
xcodebuild test \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$ID"
