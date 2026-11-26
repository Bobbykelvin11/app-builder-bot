#!/usr/bin/env bash
# Generates the android/ and ios/ platform folders (not committed) and applies
# App Builder's identity: bundle/application ID com.bobbymedia.appbuilder,
# display name "App Builder", and the Android INTERNET permission.
# Usage: tool/prepare_platforms.sh [android,ios]
set -euo pipefail
cd "$(dirname "$0")/.."
PLATFORMS="${1:-android,ios}"
APP_NAME="App Builder"

flutter create --org com.bobbymedia --project-name appbuilder --platforms="$PLATFORMS" .

MANIFEST=android/app/src/main/AndroidManifest.xml
if [ -f "$MANIFEST" ]; then
  perl -0pi -e 's/android:label="[^"]*"/android:label="'"$APP_NAME"'"/' "$MANIFEST"
  if ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
    perl -0pi -e 's#(<manifest[^>]*>)#$1\n    <uses-permission android:name="android.permission.INTERNET"/>#' "$MANIFEST"
  fi
  grep -q 'applicationId = "com.bobbymedia.appbuilder"' android/app/build.gradle.kts \
    || { echo "Unexpected Android applicationId" >&2; exit 1; }
fi

PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ]; then
  perl -0pi -e 's#(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)#${1}'"$APP_NAME"'${2}#' "$PLIST"
  grep -q 'PRODUCT_BUNDLE_IDENTIFIER = com.bobbymedia.appbuilder;' ios/Runner.xcodeproj/project.pbxproj \
    || { echo "Unexpected iOS bundle identifier" >&2; exit 1; }
fi
echo "Platforms ready: $PLATFORMS"
