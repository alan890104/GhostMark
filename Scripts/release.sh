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
dmg_path="$dist_dir/GhostMark.dmg"
checksum_path="$dist_dir/GhostMark.dmg.sha256"
staging_dir="$(mktemp -d)"
trap 'rm -rf "$staging_dir"' EXIT

GHOSTMARK_VERSION="$version" \
GHOSTMARK_BUILD="$build_number" \
GHOSTMARK_SIGNING_IDENTITY="$signing_identity" \
GHOSTMARK_UNIVERSAL=1 \
  "$project_dir/Scripts/build-app.sh" >/dev/null

codesign --verify --deep --strict --verbose=2 "$project_dir/GhostMark.app"
spctl --assess --type execute --verbose=2 "$project_dir/GhostMark.app"

mkdir -p "$dist_dir"
cp -R "$project_dir/GhostMark.app" "$staging_dir/GhostMark.app"
ln -s /Applications "$staging_dir/Applications"
hdiutil create \
  -volname GhostMark \
  -srcfolder "$staging_dir" \
  -format UDZO \
  -ov \
  "$dmg_path" >/dev/null
codesign --force --timestamp --sign "$signing_identity" "$dmg_path"

notary_profile="${GHOSTMARK_NOTARY_PROFILE:-}"
if [[ -z "$notary_profile" ]]; then
  notary_profile="$(
    security dump-keychain 2>/dev/null \
      | sed -n 's/.*"svce"<blob>="com\.apple\.gke\.notary\.tool\.\([^"]*\)".*/\1/p' \
      | sort -u \
      | head -1
  )"
fi

if [[ -n "$notary_profile" ]]; then
  xcrun notarytool submit "$dmg_path" --keychain-profile "$notary_profile" --wait
elif [[ -n "${GHOSTMARK_ASC_KEY:-}" && -n "${GHOSTMARK_ASC_KEY_ID:-}" ]]; then
  notary_args=(--key "$GHOSTMARK_ASC_KEY" --key-id "$GHOSTMARK_ASC_KEY_ID")
  if [[ -n "${GHOSTMARK_ASC_ISSUER:-}" ]]; then
    notary_args+=(--issuer "$GHOSTMARK_ASC_ISSUER")
  fi
  xcrun notarytool submit "$dmg_path" $notary_args --wait
else
  echo "No notarization credential is available in Keychain." >&2
  echo "Create one with: xcrun notarytool store-credentials GhostMark-notary" >&2
  exit 1
fi

xcrun stapler staple "$dmg_path"
xcrun stapler validate "$dmg_path"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg_path"

(cd "$dist_dir" && shasum -a 256 GhostMark.dmg > "${checksum_path:t}")

git tag -a "$version_tag" -m "GhostMark $version"
git push origin "$version_tag"
gh release create \
  "$version_tag" \
  "$dmg_path#GhostMark.dmg" \
  "$checksum_path#SHA-256" \
  --title "GhostMark $version" \
  --generate-notes \
  --latest

echo "Released $version_tag"
