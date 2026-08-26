#!/bin/sh
# Run package tests on a real iPhone simulator (never macOS).
# Swift package schemes on CI often only list placeholder destinations in
# `xcodebuild -showdestinations`; simctl is the source of truth.
set -eu

SCHEME="${1:-XMoneyPaymentSheet-Package}"

echo "==> Simulator devices (available)"
xcrun simctl list devices available || true

# First available iPhone UDID. Lines look like:
#     iPhone 16 (AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE) (Shutdown)
UDID=$(xcrun simctl list devices available | awk '
  /iPhone/ {
    if (match($0, /\([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\)/)) {
      print substr($0, RSTART + 1, RLENGTH - 2)
      exit
    }
  }
')

if [ -z "$UDID" ]; then
  echo "==> No iPhone simulator installed; creating one"
  RUNTIME=$(xcrun simctl list runtimes | awk '
    /iOS/ && /com.apple.CoreSimulator.SimRuntime/ {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /com.apple.CoreSimulator.SimRuntime.iOS/) {
          gsub(/[()]/, "", $i)
          print $i
          exit
        }
      }
    }
  ')
  DEVICETYPE=$(xcrun simctl list devicetypes | awk '
    /iPhone 16 \(/ {
      id = $NF
      gsub(/[()]/, "", id)
      print id
      found = 1
      exit
    }
    /iPhone 15 \(/ { fallback = $NF }
    END {
      if (!found && fallback != "") {
        gsub(/[()]/, "", fallback)
        print fallback
      }
    }
  ')
  if [ -z "$RUNTIME" ] || [ -z "$DEVICETYPE" ]; then
    echo "Could not find an iOS runtime / iPhone device type:"
    xcrun simctl list runtimes
    xcrun simctl list devicetypes
    exit 1
  fi
  echo "==> Creating $DEVICETYPE on $RUNTIME"
  UDID=$(xcrun simctl create "CI iPhone" "$DEVICETYPE" "$RUNTIME")
fi

echo "==> Booting $UDID"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b

echo "==> Testing $SCHEME on iOS Simulator id=$UDID"
xcodebuild test \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -parallel-testing-enabled NO
