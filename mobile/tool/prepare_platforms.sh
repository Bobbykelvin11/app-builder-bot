#!/usr/bin/env bash
# Generates the android/ and ios/ platform folders (not committed) and applies
# App Builder's identity: bundle/application ID com.bobbymedia.appbuilder,
# display name "App Builder", the Android INTERNET permission (model download +
# optional server mode) and the iOS 16.4 deployment target that llamadart
# (on-device llama.cpp) requires.
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
  # llamadart / llama.cpp XCFrameworks need iOS 16.4+.
  perl -pi -e 's/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;/IPHONEOS_DEPLOYMENT_TARGET = 16.4;/g' ios/Runner.xcodeproj/project.pbxproj
  if [ -f ios/Podfile ]; then
    perl -pi -e "s/^#?\s*platform :ios, '[0-9.]+'/platform :ios, '16.4'/" ios/Podfile
  fi
  if [ -f ios/Flutter/AppFrameworkInfo.plist ]; then
    perl -0pi -e 's#(<key>MinimumOSVersion</key>\s*<string>)[^<]*(</string>)#${1}16.4${2}#' ios/Flutter/AppFrameworkInfo.plist
  fi
  grep -q 'PRODUCT_BUNDLE_IDENTIFIER = com.bobbymedia.appbuilder;' ios/Runner.xcodeproj/project.pbxproj \
    || { echo "Unexpected iOS bundle identifier" >&2; exit 1; }
fi
echo "Platforms ready: $PLATFORMS"
