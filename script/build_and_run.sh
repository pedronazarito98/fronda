#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
if [[ "$MODE" != "--build-only" ]]; then
    pkill -x Harness >/dev/null 2>&1 || true
fi
python3 script/generate_xcode_project.py
xcodebuild -project Harness.xcodeproj -scheme Harness -configuration Debug -destination 'generic/platform=macOS' -derivedDataPath .build/xcode build -quiet
mkdir -p dist
ditto .build/xcode/Build/Products/Debug/Harness.app dist/Harness.app
python3 script/package_licenses.py dist/Harness.app
codesign --force --sign - --identifier com.harness.service dist/Harness.app/Contents/MacOS/HarnessService
codesign --force --sign - --identifier com.harness.cli dist/Harness.app/Contents/Helpers/harness
codesign --force --sign - --identifier com.harness.app dist/Harness.app
ln -sf Harness.app/Contents/Helpers/harness dist/harness
case "$MODE" in
    --build-only) ;;
    --debug) lldb -- dist/Harness.app/Contents/MacOS/Harness ;;
    --verify) open -n dist/Harness.app; sleep 2; pgrep -x Harness >/dev/null; echo "PASS: Harness.app em execução" ;;
    --logs|--telemetry) open -n dist/Harness.app; /usr/bin/log stream --info --predicate 'process == "Harness"' ;;
    run) open -n dist/Harness.app ;;
    *) echo "Uso: $0 [--build-only|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac
