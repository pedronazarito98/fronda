#!/usr/bin/env bash
# Local packaging; notarization runs only when explicitly requested with --notarize.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
: "${HARNESS_SIGN_IDENTITY:?Set HARNESS_SIGN_IDENTITY to your Developer ID Application identity}"
if [[ "$HARNESS_SIGN_IDENTITY" != 'Developer ID Application:'* ]]; then
    echo 'A release requires a Developer ID Application identity.' >&2
    exit 2
fi
python3 script/generate_xcode_project.py
xcodebuild -project Harness.xcodeproj -scheme Harness -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath .build/release build -quiet
mkdir -p dist/release
ditto .build/release/Build/Products/Release/Harness.app dist/release/Harness.app
python3 script/package_licenses.py dist/release/Harness.app
for helper in Contents/Helpers/harness Contents/MacOS/HarnessService; do
    codesign --force --options runtime --timestamp --sign "$HARNESS_SIGN_IDENTITY" "dist/release/Harness.app/$helper"
done
codesign --force --options runtime --timestamp --sign "$HARNESS_SIGN_IDENTITY" dist/release/Harness.app
codesign --verify --deep --strict --verbose=2 dist/release/Harness.app
ditto -c -k --keepParent dist/release/Harness.app dist/release/Harness.zip
if [[ "${1:-}" == '--notarize' ]]; then
    : "${HARNESS_NOTARY_PROFILE:?Set HARNESS_NOTARY_PROFILE to an existing notarytool Keychain profile}"
    xcrun notarytool submit dist/release/Harness.zip --keychain-profile "$HARNESS_NOTARY_PROFILE" --wait
    xcrun stapler staple dist/release/Harness.app
    xcrun stapler validate dist/release/Harness.app
    spctl --assess --type execute --verbose=2 dist/release/Harness.app
    ditto -c -k --keepParent dist/release/Harness.app dist/release/Harness.zip
fi
shasum -a 256 dist/release/Harness.zip > dist/release/Harness.zip.sha256
printf '%s\n' 'Package: dist/release/Harness.zip. Check notarization status separately.'
