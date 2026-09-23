#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
case "${1:-}" in
    "") xcrun swift-format lint --strict --configuration .swift-format --recursive Sources Tests Package.swift ;;
    --fix) xcrun swift-format format --in-place --configuration .swift-format --recursive Sources Tests Package.swift ;;
    *) echo "Uso: script/lint.sh [--fix]" >&2; exit 2 ;;
esac
