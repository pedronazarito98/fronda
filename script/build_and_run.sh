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
# Keep existing local hooks and launchd paths valid during the product rename.
if [[ -d dist/Harness.app && ! -L dist/Harness.app && ! -e dist/Fronda.app ]]; then
    mv dist/Harness.app dist/Fronda.app
fi
ditto .build/xcode/Build/Products/Debug/Fronda.app dist/Fronda.app
python3 script/package_licenses.py dist/Fronda.app
codesign --force --sign - --identifier com.harness.service dist/Fronda.app/Contents/MacOS/HarnessService
codesign --force --sign - --identifier com.harness.cli dist/Fronda.app/Contents/Helpers/harness
codesign --force --sign - --identifier com.harness.app dist/Fronda.app
ln -sf Fronda.app/Contents/Helpers/harness dist/fronda
ln -sf Fronda.app/Contents/Helpers/harness dist/harness
if [[ ! -e dist/Harness.app || -L dist/Harness.app ]]; then
    ln -sfn Fronda.app dist/Harness.app
fi
case "$MODE" in
    --build-only) ;;
    --debug) lldb -- dist/Fronda.app/Contents/MacOS/Harness ;;
    --verify) open -n dist/Fronda.app; sleep 2; pgrep -x Harness >/dev/null; echo "PASS: Fronda.app em execução" ;;
    --logs|--telemetry) open -n dist/Fronda.app; /usr/bin/log stream --info --predicate 'process == "Harness"' ;;
    run) open -n dist/Fronda.app ;;
    *) echo "Uso: $0 [--build-only|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac
