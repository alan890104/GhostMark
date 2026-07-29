#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
app_dir="$project_dir/GhostMark.app"

cd "$project_dir"
if [[ "${GHOSTMARK_UNIVERSAL:-1}" == "1" ]]; then
  swift build -c release --arch arm64 --arch x86_64
  executable_path="$project_dir/.build/apple/Products/Release/GhostMark"
else
  swift build -c release
  executable_path="$project_dir/.build/release/GhostMark"
fi

mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$executable_path" "$app_dir/Contents/MacOS/GhostMark"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
if [[ -f "$project_dir/Resources/AppIcon.icns" ]]; then
  cp "$project_dir/Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
fi

if [[ -n "${GHOSTMARK_VERSION:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $GHOSTMARK_VERSION" "$app_dir/Contents/Info.plist"
fi
if [[ -n "${GHOSTMARK_BUILD:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $GHOSTMARK_BUILD" "$app_dir/Contents/Info.plist"
fi

signing_identity="${GHOSTMARK_SIGNING_IDENTITY:--}"
if [[ "$signing_identity" == "-" ]]; then
  codesign --force --deep --sign - "$app_dir"
else
  codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "$signing_identity" \
    "$app_dir"
fi
echo "$app_dir"
