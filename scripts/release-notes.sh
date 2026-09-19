#!/bin/bash
set -euo pipefail
exec python3 "$(dirname "$0")/release-metadata.py" "${1:?Usage: release-notes.sh vX.Y.Z}"
