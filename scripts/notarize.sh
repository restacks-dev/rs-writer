#!/bin/bash
set -euo pipefail
set +x
artifact="${1:?Usage: notarize.sh ARTIFACT OUTPUT_JSON}"
result="${2:?Supply notarization result JSON path}"
for name in APPLE_ID APPLE_TEAM_ID APPLE_APP_SPECIFIC_PASSWORD; do
  [[ -n "${!name:-}" ]] || { printf 'Missing required secret: %s\n' "$name" >&2; exit 1; }
done
[[ -f "$artifact" ]] || { printf 'Artifact does not exist: %s\n' "$artifact" >&2; exit 1; }
mkdir -p "$(dirname "$result")"
if ! xcrun notarytool submit "$artifact" --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --wait --timeout 30m --output-format json > "$result"; then
  printf 'Notarization command failed; inspect %s. Nothing will be published.\n' "$result" >&2
  exit 1
fi
python3 - "$result" <<'PY'
import json, sys
with open(sys.argv[1]) as source:
    result = json.load(source)
if result.get("status") != "Accepted":
    sys.exit("Notarization was not Accepted; nothing will be published. See " + sys.argv[1])
print("Apple accepted notarization submission " + result["id"])
PY
