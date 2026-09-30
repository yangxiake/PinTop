#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' PinTop/Resources/Info.plist)
architecture=$(uname -m)
if [[ "$architecture" != arm64 ]]; then
  echo "此预览包只在 Apple Silicon 构建和验证" >&2
  exit 1
fi

xcodebuild -quiet -project PinTop.xcodeproj -scheme PinTop -configuration Release \
  -destination 'platform=macOS' -derivedDataPath DerivedData ARCHS=arm64 build
app="$PWD/build/PinTop.app"
codesign --verify --deep --strict "$app"
if [[ "$(lipo -archs "$app/Contents/MacOS/PinTop")" != arm64 ]]; then
  echo "安装包架构不是 arm64" >&2
  exit 1
fi
mkdir -p dist
archive_name="PinTop-v${version}-macos-${architecture}.zip"
archive="$PWD/dist/$archive_name"
rm -f "$archive" "$archive.sha256"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
(cd dist && shasum -a 256 "$archive_name" > "$archive_name.sha256")
unzip -t "$archive" >/dev/null
echo "$archive"
cat "$archive.sha256"
