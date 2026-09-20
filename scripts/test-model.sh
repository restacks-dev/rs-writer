#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/model-tests/module-cache
swiftc -parse-as-library -module-cache-path build/model-tests/module-cache \
  Sources/WriterCore/*.swift Sources/RSWriter/WriterModel.swift \
  ModelTests/WriterModelTests.swift -o build/model-tests/WriterModelTests
build/model-tests/WriterModelTests
