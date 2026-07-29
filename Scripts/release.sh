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

identities="$(security find-identity -v)"
application_identity="$(
  printf '%s\n' "$identities" \
    | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
    | head -1
)"
installer_identity="$(
  printf '%s\n' "$identities" \
    | sed -n 's/.*"\(Developer ID Installer:[^"]*\)".*/\1/p' \
    | head -1
)"

if [[ -z "$application_identity" ]]; then
  echo "A Developer ID Application identity is required." >&2
  exit 1
fi
if [[ -z "$installer_identity" ]]; then
  echo "A Developer ID Installer identity is required." >&2
  exit 1
fi

notary_profile="${GHOSTMARK_NOTARY_PROFILE:-GhostMark-notary}"
if ! xcrun notarytool history \
  --keychain-profile "$notary_profile" \
  >/dev/null 2>&1; then
  echo "A notarytool Keychain profile is required." >&2
  echo "Create one with: xcrun notarytool store-credentials GhostMark-notary" >&2
  exit 1
fi

version="${version_tag#v}"
build_number="$(date -u +%Y%m%d%H%M)"
dist_dir="$project_dir/dist"
pkg_path="$dist_dir/GhostMark.pkg"
checksum_path="$dist_dir/GhostMark.pkg.sha256"
release_temp="$(mktemp -d "${TMPDIR%/}/GhostMark.release.XXXXXX")"
package_root="$release_temp/root"
trap 'rm -rf "$release_temp"' EXIT

GHOSTMARK_VERSION="$version" \
GHOSTMARK_BUILD="$build_number" \
GHOSTMARK_SIGNING_IDENTITY="$application_identity" \
GHOSTMARK_UNIVERSAL=1 \
  "$project_dir/Scripts/build-app.sh" >/dev/null

codesign --verify --deep --strict --verbose=2 "$project_dir/GhostMark.app"

mkdir -p "$dist_dir"
mkdir -p "$package_root/Applications"
COPYFILE_DISABLE=1 ditto --norsrc --noextattr \
  "$project_dir/GhostMark.app" \
  "$package_root/Applications/GhostMark.app"
xattr -cr "$package_root/Applications/GhostMark.app"
codesign --verify --deep --strict --verbose=2 \
  "$package_root/Applications/GhostMark.app"

pkgbuild \
  --root "$package_root" \
  --component-plist "$project_dir/Resources/InstallerComponents.plist" \
  --identifier com.ghostmark.GhostMark.pkg \
  --version "$version" \
  --sign "$installer_identity" \
  "$pkg_path"

pkgutil --expand "$pkg_path" "$release_temp/expanded"
rg -q 'relocatable="false"' "$release_temp/expanded/PackageInfo"
rg -q 'path="\./Applications/GhostMark\.app"' "$release_temp/expanded/PackageInfo"
pkgutil --check-signature "$pkg_path"
xcrun notarytool submit "$pkg_path" --keychain-profile "$notary_profile" --wait
xcrun stapler staple "$pkg_path"
xcrun stapler validate "$pkg_path"
spctl --assess --type install --verbose=2 "$pkg_path"

(cd "$dist_dir" && shasum -a 256 GhostMark.pkg > "${checksum_path:t}")

git tag -a "$version_tag" -m "GhostMark $version"
git push origin "$version_tag"
gh release create \
  "$version_tag" \
  "$pkg_path#GhostMark.pkg" \
  "$checksum_path#SHA-256" \
  --title "GhostMark $version" \
  --generate-notes \
  --latest

echo "Released $version_tag"
