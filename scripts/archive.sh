#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
team_id="${1:?Gebruik: ./scripts/archive.sh APPLE_TEAM_ID [bundle.identifier]}"
bundle_id="${2:-nl.rs.writer}"
if [[ ! "$team_id" =~ ^[A-Z0-9]{10}$ ]]; then
  printf 'Geef je Apple Team ID op (10 hoofdletters/cijfers).\n' >&2
  exit 1
fi
if [[ ! "$bundle_id" =~ ^[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+$ ]]; then
  printf 'Ongeldige bundle identifier.\n' >&2
  exit 1
fi
xcodebuild -project RSWriter.xcodeproj -scheme RSWriter -configuration Release \
  -destination 'generic/platform=macOS' -archivePath build/RSWriter.xcarchive \
  -allowProvisioningUpdates DEVELOPMENT_TEAM="$team_id" PRODUCT_BUNDLE_IDENTIFIER="$bundle_id" \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO archive
printf '\nArchief: %s/build/RSWriter.xcarchive\nOpen het archief in Xcode Organizer voor Developer ID-distributie en notarization.\n' "$PWD"
