#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodebuild -project RSWriter.xcodeproj -scheme RSWriter -configuration Release \
  -derivedDataPath build -destination 'generic/platform=macOS' \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build
printf '\nApp: %s/build/Build/Products/Release/RS Writer.app\n' "$PWD"
