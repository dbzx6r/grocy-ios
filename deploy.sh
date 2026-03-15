#!/bin/bash
set -e

DEVELOPER_DIR="/Applications/Xcode 2.app/Contents/Developer"
export DEVELOPER_DIR

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"
BUNDLE_ID="com.dbzx6r.grocy-v2"
DEVICE_ID="394D755A-346F-514C-B538-CDC88EDF979F"
XCODE_DEST="id=00008130-001178323CC0001C"

echo "▶ Building GrocyV2..."
xcodebuild \
  -project "$PROJECT_DIR/GrocyV2.xcodeproj" \
  -scheme GrocyV2 \
  -destination "$XCODE_DEST" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=V6Q6Z5WZZK \
  build 2>&1 | grep -E "error:|warning: .*error|BUILD (SUCCEEDED|FAILED)|Signing"

APP_PATH=$(find "$DERIVED_DATA/GrocyV2-"*/Build/Products/Debug-iphoneos/GrocyV2.app -maxdepth 0 2>/dev/null | head -1)
if [ -z "$APP_PATH" ]; then
  echo "✗ Could not find built .app"
  exit 1
fi

echo "▶ Installing to device..."
xcrun devicectl device install app \
  --device "$DEVICE_ID" \
  "$APP_PATH" 2>&1 | grep -v "^$"

echo "▶ Launching app..."
xcrun devicectl device process launch \
  --device "$DEVICE_ID" \
  "$BUNDLE_ID" 2>&1 | grep -v "^$"

echo "✓ Done — Grocy v2 deployed and launched on device"
