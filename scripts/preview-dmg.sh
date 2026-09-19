#!/bin/bash
# A local packaging preview, intentionally excluded from release outputs.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
app="${1:-$root/build/Build/Products/Release/RS Writer.app}"
output="$root/build/preview/RS-Writer-UNSIGNED-PREVIEW.dmg"
"$root/scripts/make-dmg.sh" "$app" "$output"
printf '\nUNSIGNED PREVIEW: alleen voor controle van de vormgeving, niet verspreiden.\n'
