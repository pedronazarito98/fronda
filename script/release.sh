#!/usr/bin/env bash
# Local packaging; notarization runs only when explicitly requested with --notarize.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
HARNESS_SIGN_IDENTITY="${HARNESS_SIGN_IDENTITY:-Developer ID Application: Pedro Henrique Lopes Nazarito (63LS85SD8D)}"
if [[ "$HARNESS_SIGN_IDENTITY" != 'Developer ID Application:'* ]]; then
    echo 'A release requires a Developer ID Application identity.' >&2
    exit 2
fi
mkdir -p .build
RELEASE_DIR="$(mktemp -d "$ROOT_DIR/.build/developer-id.XXXXXX")"
xcodebuild -project Harness.xcodeproj -scheme Harness -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$RELEASE_DIR/DerivedData" build -quiet
ditto "$RELEASE_DIR/DerivedData/Build/Products/Release/Fronda.app" "$RELEASE_DIR/Fronda.app"
python3 script/package_licenses.py "$RELEASE_DIR/Fronda.app"
for helper in Contents/Helpers/harness Contents/MacOS/HarnessService; do
    codesign --force --options runtime --timestamp --sign "$HARNESS_SIGN_IDENTITY" "$RELEASE_DIR/Fronda.app/$helper"
done
codesign --force --options runtime --timestamp --sign "$HARNESS_SIGN_IDENTITY" "$RELEASE_DIR/Fronda.app"
codesign --verify --deep --strict --verbose=2 "$RELEASE_DIR/Fronda.app"
ditto -c -k --keepParent "$RELEASE_DIR/Fronda.app" "$RELEASE_DIR/Fronda.zip"
if [[ "${1:-}" == '--notarize' ]]; then
    : "${HARNESS_NOTARY_PROFILE:?Set HARNESS_NOTARY_PROFILE to an existing notarytool Keychain profile}"
    xcrun notarytool submit "$RELEASE_DIR/Fronda.zip" --keychain-profile "$HARNESS_NOTARY_PROFILE" --wait
    xcrun stapler staple "$RELEASE_DIR/Fronda.app"
    xcrun stapler validate "$RELEASE_DIR/Fronda.app"
    spctl --assess --type execute --verbose=2 "$RELEASE_DIR/Fronda.app"
    ditto -c -k --keepParent "$RELEASE_DIR/Fronda.app" "$RELEASE_DIR/Fronda.zip"
fi
shasum -a 256 "$RELEASE_DIR/Fronda.zip" > "$RELEASE_DIR/Fronda.zip.sha256"
printf 'Package: %s/Fronda.zip. Check notarization status separately.\n' "$RELEASE_DIR"
