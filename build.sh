#!/bin/bash
# Build MenuMeters (Release, arm64), install to /Applications, and launch.
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
DERIVED="${DERIVED_DATA_PATH:-/tmp/MenuMetersBuild}"
APP_SRC="${DERIVED}/Build/Products/Release/MenuMeters.app"
APP_DST="/Applications/MenuMeters.app"

cd "$ROOT"

echo "==> Building MenuMeters (No Sparkle, Release, arm64)..."
xcodebuild -project MenuMeters.xcodeproj \
  -scheme "MenuMeters No Sparkle" \
  -configuration Release \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM= \
  ONLY_ACTIVE_ARCH=YES \
  ARCHS=arm64 \
  -derivedDataPath "$DERIVED" \
  build

echo "==> Installing to ${APP_DST}..."
killall MenuMeters 2>/dev/null || true
rm -rf "${APP_DST}"
cp -R "${APP_SRC}" "${APP_DST}"
codesign --force --deep --sign - "${APP_DST}"
xattr -dr com.apple.quarantine "${APP_DST}" 2>/dev/null || true

mkdir -p "${ROOT}/build"
rm -rf "${ROOT}/build/MenuMeters.app"
cp -R "${APP_SRC}" "${ROOT}/build/MenuMeters.app"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP_DST}/Contents/Info.plist" 2>/dev/null || echo '?')"
echo "==> Done. MenuMeters ${VERSION} installed."
echo "    ${APP_DST}"
echo "    ${ROOT}/build/MenuMeters.app"

if [[ "${NO_OPEN:-}" != "1" ]]; then
  open "${APP_DST}"
fi
