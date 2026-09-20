#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="$PWD/build/preview-tests/PreviewTests.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" build/preview-tests/module-cache
cp Resources/marked.js Resources/purify.js "$app/Contents/Resources/"
python3 - "$app/Contents/Info.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'wb') as target:
    plistlib.dump({
        'CFBundleIdentifier': 'nl.rs.writer.preview-tests',
        'CFBundleName': 'PreviewTests',
        'CFBundleExecutable': 'PreviewTests',
        'CFBundlePackageType': 'APPL',
        'LSUIElement': True,
    }, target)
PY
swiftc -parse-as-library -module-cache-path build/preview-tests/module-cache \
  Sources/WriterCore/*.swift Sources/RSWriter/WriterModel.swift Sources/RSWriter/BrandPalette.swift Sources/RSWriter/MarkdownPreview.swift \
  PreviewTests/MarkdownPreviewTests.swift -o "$app/Contents/MacOS/PreviewTests"
codesign --force --sign - --options runtime --entitlements Resources/RSWriter.entitlements "$app"
"$app/Contents/MacOS/PreviewTests"
