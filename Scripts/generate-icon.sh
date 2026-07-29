#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
source_svg="$project_dir/docs/assets/ghostmark-icon.svg"
render_dir="$(mktemp -d)"
iconset_dir="$(mktemp -d)/AppIcon.iconset"
trap 'rm -rf "$render_dir" "${iconset_dir:h}"' EXIT

mkdir -p "$iconset_dir"
qlmanage -t -s 1024 -o "$render_dir" "$source_svg" >/dev/null 2>&1
rendered="$(find "$render_dir" -maxdepth 1 -type f -name '*.png' -print -quit)"
test -n "$rendered"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$rendered" \
    --out "$iconset_dir/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$rendered" \
    --out "$iconset_dir/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$iconset_dir" -o "$project_dir/Resources/AppIcon.icns"
echo "$project_dir/Resources/AppIcon.icns"
