#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-all}"
if [[ "$mode" != "all" && "$mode" != "--unit-only" ]]; then
    echo "Uso: script/validate.sh [--unit-only]" >&2
    exit 2
fi
mkdir -p .build/qa
qa_output=$(mktemp -d "$PWD/.build/qa/run-XXXXXX")
trap 'echo "Relatórios de QA: $qa_output"' EXIT
script/lint.sh
echo "Lint: PASS"
swift test --disable-swift-testing --parallel --num-workers 1 --xunit-output "$qa_output/unit.xml"
test -s "$qa_output/unit.xml"
echo "XCTest (SwiftPM): PASS"
if [[ "$mode" == "--unit-only" ]]; then
    echo "XCUITest e pacote: NOT_RUN (--unit-only)"
    exit 0
fi
python3 script/generate_xcode_project.py
xcodebuild -project Harness.xcodeproj -scheme Harness -configuration Debug \
    -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath .build/xcode \
    -parallel-testing-enabled NO -test-timeouts-enabled YES \
    -maximum-test-execution-time-allowance 120 \
    -resultBundlePath "$qa_output/Harness.xcresult" ONLY_ACTIVE_ARCH=YES test -quiet
echo "XCTest e XCUITest (Xcode): PASS"
script/build_and_run.sh --build-only
codesign --verify --deep --strict dist/Harness.app
echo "Build universal e assinatura ad hoc: PASS"
