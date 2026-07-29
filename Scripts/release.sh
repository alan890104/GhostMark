#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
version_tag="${1:-}"

if [[ ! "$version_tag" =~ '^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$' ]]; then
  echo "usage: ./Scripts/release.sh vX.Y.Z" >&2
  exit 2
fi

cd "$project_dir"

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not authenticated." >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Commit local changes before releasing." >&2
  exit 1
fi

if git rev-parse "$version_tag" >/dev/null 2>&1; then
  echo "Tag already exists: $version_tag" >&2
  exit 1
fi

identities="$(security find-identity -v -p codesigning)"
signing_identity="$(printf '%s\n' "$identities" | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -1)"
if [[ -z "$signing_identity" ]]; then
  echo "A Developer ID Application identity is required." >&2
  exit 1
fi

version="${version_tag#v}"
build_number="$(date -u +%Y%m%d%H%M)"
dist_dir="$project_dir/dist"
zip_path="$dist_dir/GhostMark.zip"
checksum_path="$dist_dir/GhostMark.zip.sha256"
release_work="$(mktemp -d)"
archive_path="$release_work/GhostMark.xcarchive"
export_options="$release_work/ExportOptions.plist"
notarized_dir="$release_work/notarized"
verification_dir="$release_work/verify"

cleanup() {
  [[ -n "${release_work:-}" && -d "$release_work" ]] && rm -rf "$release_work"
}
trap cleanup EXIT

GHOSTMARK_VERSION="$version" \
GHOSTMARK_BUILD="$build_number" \
GHOSTMARK_SIGNING_IDENTITY="$signing_identity" \
GHOSTMARK_UNIVERSAL=1 \
  "$project_dir/Scripts/build-app.sh" >/dev/null

codesign --verify --deep --strict --verbose=2 "$project_dir/GhostMark.app"
team_id="$(codesign -dv --verbose=4 "$project_dir/GhostMark.app" 2>&1 | sed -n 's/^TeamIdentifier=//p' | head -1)"
if [[ -z "$team_id" ]]; then
  echo "The signed app does not include a Team ID." >&2
  exit 1
fi

mkdir -p "$archive_path/Products/Applications" "$notarized_dir" "$verification_dir" "$dist_dir"
ditto "$project_dir/GhostMark.app" "$archive_path/Products/Applications/GhostMark.app"

plutil -create xml1 "$archive_path/Info.plist"
/usr/libexec/PlistBuddy -c "Add :ArchiveVersion integer 2" "$archive_path/Info.plist"
plutil -insert CreationDate -date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$archive_path/Info.plist"
/usr/libexec/PlistBuddy -c "Add :Name string GhostMark" "$archive_path/Info.plist"
/usr/libexec/PlistBuddy -c "Add :SchemeName string GhostMark" "$archive_path/Info.plist"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties dict" "$archive_path/Info.plist"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:ApplicationPath string Applications/GhostMark.app" "$archive_path/Info.plist"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:Architectures array" "$archive_path/Info.plist"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:Architectures:0 string arm64" "$archive_path/Info.plist"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:Architectures:1 string x86_64" "$archive_path/Info.plist"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:CFBundleIdentifier string com.ghostmark.GhostMark" "$archive_path/Info.plist"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:CFBundleShortVersionString string $version" "$archive_path/Info.plist"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:CFBundleVersion string $build_number" "$archive_path/Info.plist"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:SigningIdentity string 'Developer ID Application'" "$archive_path/Info.plist"
/usr/libexec/PlistBuddy -c "Add :ApplicationProperties:Team string $team_id" "$archive_path/Info.plist"

plutil -create xml1 "$export_options"
/usr/libexec/PlistBuddy -c "Add :destination string upload" "$export_options"
/usr/libexec/PlistBuddy -c "Add :method string developer-id" "$export_options"
/usr/libexec/PlistBuddy -c "Add :signingStyle string manual" "$export_options"
/usr/libexec/PlistBuddy -c "Add :teamID string $team_id" "$export_options"

echo "Uploading $version_tag to Apple's notary service…"
xcodebuild \
  -exportArchive \
  -archivePath "$archive_path" \
  -exportPath "$release_work/upload" \
  -exportOptionsPlist "$export_options" \
  -allowProvisioningUpdates

xcodebuild \
  -exportNotarizedApp \
  -archivePath "$archive_path" \
  -exportPath "$notarized_dir"

notarized_app="$notarized_dir/GhostMark.app"
xcrun stapler validate "$notarized_app"
codesign --verify --deep --strict --verbose=2 "$notarized_app"
spctl --assess --type execute --verbose=2 "$notarized_app"

ditto -c -k --sequesterRsrc --keepParent "$notarized_app" "$zip_path"
ditto -x -k "$zip_path" "$verification_dir"
xattr -w com.apple.quarantine "0083;$(printf '%x' "$(date +%s)");GhostMark;" "$verification_dir/GhostMark.app"
spctl --assess --type execute --verbose=2 "$verification_dir/GhostMark.app"

(cd "$dist_dir" && shasum -a 256 GhostMark.zip > "${checksum_path:t}")

git tag -a "$version_tag" -m "GhostMark $version"
git push origin "$version_tag"
gh release create \
  "$version_tag" \
  "$zip_path#GhostMark.zip" \
  "$checksum_path#SHA-256" \
  --title "GhostMark $version" \
  --generate-notes \
  --latest

echo "Released $version_tag"
