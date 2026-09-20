#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift test
bash scripts/test-model.sh
