#!/bin/bash
# Opens the app in the iOS Simulator in demo mode and screenshots each tab into shots/.
set -euo pipefail

UDID="$1"
APP="build/sim/Build/Products/Debug-iphonesimulator/LionClub.app"
BUNDLE_ID="io.github.pokerbanana.lionclub"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 || true
xcrun simctl install "$UDID" "$APP"

mkdir -p shots
for tab in home checks; do
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -demoTab "$tab"
  sleep 8
  xcrun simctl io "$UDID" screenshot "shots/$tab.png"
done
ls -l shots
