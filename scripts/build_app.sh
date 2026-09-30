#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
xcodebuild -project PinTop.xcodeproj -scheme PinTop -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath DerivedData build
APP="$PWD/build/PinTop.app"
codesign --verify --deep --strict "$APP"
echo "$APP"
