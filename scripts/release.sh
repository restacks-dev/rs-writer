#!/bin/bash
# Produces verified distributables locally; publishing belongs to release.yml.
set -euo pipefail
set +x
cd "$(dirname "$0")/.."
tag="${1:?Usage: release.sh vX.Y.Z}"
notes="$(./scripts/release-notes.sh "$tag")"
for name in APPLE_SIGNING_IDENTITY APPLE_TEAM_ID APPLE_ID APPLE_APP_SPECIFIC_PASSWORD; do
  [[ -n "${!name:-}" ]] || { printf 'Missing required secret: %s\n' "$name" >&2; exit 1; }
done
[[ "$APPLE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || { printf 'Invalid Apple Team ID.\n' >&2; exit 1; }
[[ "$APPLE_SIGNING_IDENTITY" == "Developer ID Application: "*" ($APPLE_TEAM_ID)" ]] || {
  printf 'Use a Developer ID Application identity belonging to APPLE_TEAM_ID.\n' >&2; exit 1;
}
build_number="${RELEASE_BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}"
[[ "$build_number" =~ ^[1-9][0-9]{0,3}$ ]] || { printf 'Build number must be 1..9999.\n' >&2; exit 1; }
version="${tag#v}"
mkdir -p dist build/notary
dmg="$PWD/dist/RS-Writer-$version-universal.dmg"
[[ ! -e "$dmg" ]] || { printf 'Output already exists: %s\n' "$dmg" >&2; exit 1; }
sign_flags='--timestamp'
codesign_keychain=()
if [[ -n "${RS_WRITER_KEYCHAIN_PATH:-}" ]]; then
  [[ "$RS_WRITER_KEYCHAIN_PATH" != *[[:space:]]* ]] || { printf 'Keychain path must not contain whitespace.\n' >&2; exit 1; }
  sign_flags="$sign_flags --keychain $RS_WRITER_KEYCHAIN_PATH"
  codesign_keychain=(--keychain "$RS_WRITER_KEYCHAIN_PATH")
fi
xcodebuild -project RSWriter.xcodeproj -scheme RSWriter -configuration Release \
  -derivedDataPath build/release -destination 'generic/platform=macOS' \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$APPLE_SIGNING_IDENTITY" DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  ENABLE_HARDENED_RUNTIME=YES CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  OTHER_CODE_SIGN_FLAGS="$sign_flags" MARKETING_VERSION="$version" \
  CURRENT_PROJECT_VERSION="$build_number" build
app="$PWD/build/release/Build/Products/Release/RS Writer.app"
codesign --verify --deep --strict --verbose=2 "$app"
signature="$(codesign -d --verbose=4 "$app" 2>&1)"
printf '%s\n' "$signature" | grep -Fqx "Authority=$APPLE_SIGNING_IDENTITY"
printf '%s\n' "$signature" | grep -Fqx "TeamIdentifier=$APPLE_TEAM_ID"
printf '%s\n' "$signature" | grep -Eq '^Timestamp=.+$'
printf '%s\n' "$signature" | grep -Eq '^CodeDirectory .*flags=.*\(.*runtime.*\)'
executable="$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$app/Contents/Info.plist")"
lipo "$app/Contents/MacOS/$executable" -verify_arch arm64 x86_64
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$version" ]]
codesign -d --entitlements :- "$app" > build/notary/signed-entitlements.plist 2>/dev/null
python3 - <<'PY'
import plistlib
with open('Resources/RSWriter.entitlements', 'rb') as source:
    expected = plistlib.load(source)
with open('build/notary/signed-entitlements.plist', 'rb') as source:
    actual = plistlib.load(source)
assert all(actual.get(key) == value for key, value in expected.items()), 'Missing app entitlements'
assert not actual.get('com.apple.security.get-task-allow'), 'Debug entitlement in release'
PY
zip_path="$PWD/build/notary/RS-Writer-$version.zip"
rm -f "$zip_path"
ditto -c -k --keepParent "$app" "$zip_path"
./scripts/notarize.sh "$zip_path" build/notary/app.json
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"
./scripts/make-dmg.sh "$app" "$dmg"
codesign --sign "$APPLE_SIGNING_IDENTITY" --timestamp ${codesign_keychain[@]+"${codesign_keychain[@]}"} "$dmg"
codesign --verify --strict --verbose=2 "$dmg"
./scripts/notarize.sh "$dmg" build/notary/dmg.json
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
codesign --verify --strict --verbose=2 "$dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
printf '%s\n' "$notes" > dist/RELEASE_NOTES.md
cat >> dist/RELEASE_NOTES.md <<'NOTES'

### Installeren

1. Download de DMG hieronder en open deze.
2. Sleep **RS Writer** naar **Applications / Apps**.
3. Werp de DMG uit en open RS Writer vanuit Apps.

Voor macOS 14 en nieuwer, op Apple Silicon en Intel. Sluit RS Writer eerst af
bij een update. Je documenten blijven in je eigen bibliotheekmap.
macOS kan bij de eerste start de normale bevestiging voor een download tonen.

NOTES
(cd dist && shasum -a 256 "$(basename "$dmg")" > SHA256SUMS)
printf '\nVerified release artifacts: %s/dist\n' "$PWD"
