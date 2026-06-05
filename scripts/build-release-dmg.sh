#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/lexi.xcodeproj}"
SCHEME="${SCHEME:-lexi}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT_DIR/build/DerivedDataRelease}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/build/release}"
TEAM_ID="${TEAM_ID:-P3X5CXXARL}"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:-Developer ID Application: Yunfan Wang (P3X5CXXARL)}"
DMG_SIGN_IDENTITY="${DMG_SIGN_IDENTITY:-$APP_SIGN_IDENTITY}"
APP_NAME="${APP_NAME:-Lexi}"
RELEASE_ENTITLEMENTS="${RELEASE_ENTITLEMENTS:-$ROOT_DIR/lexi/lexi.release.entitlements}"
SKIP_NOTARIZATION="${SKIP_NOTARIZATION:-0}"
NOTARIZE_APP_FIRST="${NOTARIZE_APP_FIRST:-1}"

usage() {
  cat <<'USAGE'
Build a Developer ID signed Lexi release DMG.

Usage:
  scripts/build-release-dmg.sh

Environment:
  APP_PATH=/path/to/Lexi.app       Use an existing app bundle instead of building.
  OUTPUT_DIR=build/release         Directory for the final DMG.
  DERIVED_DATA=build/DerivedDataRelease
  TEAM_ID=P3X5CXXARL
  APP_SIGN_IDENTITY="Developer ID Application: ..."
  DMG_SIGN_IDENTITY="$APP_SIGN_IDENTITY"
  RELEASE_ENTITLEMENTS=lexi/lexi.release.entitlements
  NOTARY_PROFILE=lexi-notary       Keychain profile for xcrun notarytool.
  SKIP_NOTARIZATION=1              Build and sign only; not for public shipping.
  NOTARIZE_APP_FIRST=0             Skip the pre-DMG app notarization pass.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

log() {
  printf '\n==> %s\n' "$1"
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist"
}

require_file() {
  if [[ ! -e "$1" ]]; then
    printf 'Missing required path: %s\n' "$1" >&2
    exit 1
  fi
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

require_command xcodebuild
require_command hdiutil
require_command codesign
require_command shasum
require_command xcrun

if [[ -z "${APP_PATH:-}" ]]; then
  require_file "$RELEASE_ENTITLEMENTS"

  log "Building $SCHEME $CONFIGURATION"
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$APP_SIGN_IDENTITY" \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    CODE_SIGN_ENTITLEMENTS="$RELEASE_ENTITLEMENTS" \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    clean build

  APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
  if [[ ! -e "$APP_PATH" && -e "$DERIVED_DATA/Build/Products/$CONFIGURATION/$SCHEME.app" ]]; then
    APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/$SCHEME.app"
  fi
fi

require_file "$APP_PATH"

VERSION="${VERSION:-$(plist_value "$APP_PATH" CFBundleShortVersionString)}"
BUILD_NUMBER="$(plist_value "$APP_PATH" CFBundleVersion)"
DMG_PATH="$OUTPUT_DIR/$APP_NAME-$VERSION.dmg"
VOLUME_NAME="${VOLUME_NAME:-$APP_NAME $VERSION}"

log "Verifying app signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
APP_SIGNING_DETAILS="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)"
printf '%s\n' "$APP_SIGNING_DETAILS" | sed -n '1,36p'
if printf '%s\n' "$APP_SIGNING_DETAILS" | grep -q '^Authority=Developer ID' &&
   ! printf '%s\n' "$APP_SIGNING_DETAILS" | grep -q '^Timestamp='; then
  printf 'Developer ID app signature is missing a secure timestamp.\n' >&2
  exit 1
fi

log "Verifying app entitlements"
APP_ENTITLEMENTS_FILE="$(mktemp)"
codesign -d --entitlements :- "$APP_PATH" >"$APP_ENTITLEMENTS_FILE" 2>/dev/null
plutil -p "$APP_ENTITLEMENTS_FILE"
if grep -q 'com.apple.security.get-task-allow' "$APP_ENTITLEMENTS_FILE"; then
  printf 'Release app must not include com.apple.security.get-task-allow.\n' >&2
  exit 1
fi
rm -f "$APP_ENTITLEMENTS_FILE"

should_notarize=0
if [[ "$SKIP_NOTARIZATION" != "1" && -n "${NOTARY_PROFILE:-}" ]]; then
  should_notarize=1
fi

if [[ "$should_notarize" == "1" && "$NOTARIZE_APP_FIRST" == "1" ]]; then
  log "Notarizing app before DMG packaging"
  APP_ZIP="$(mktemp -t "$APP_NAME-$VERSION-app.XXXXXX.zip")"
  ditto -c -k --keepParent "$APP_PATH" "$APP_ZIP"
  xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  rm -f "$APP_ZIP"
  xcrun stapler staple "$APP_PATH"
  xcrun stapler validate "$APP_PATH"
fi

log "Creating DMG"
mkdir -p "$OUTPUT_DIR"
STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT

ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  "$DMG_PATH"

log "Signing DMG"
codesign --force --timestamp --sign "$DMG_SIGN_IDENTITY" "$DMG_PATH"
codesign --verify --verbose=2 "$DMG_PATH"

if [[ "$should_notarize" == "1" ]]; then
  log "Notarizing DMG"
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"
else
  log "Skipping notarization"
  printf 'Set NOTARY_PROFILE to a notarytool keychain profile before shipping this DMG publicly.\n'
fi

log "Verifying DMG contents"
hdiutil verify "$DMG_PATH"
MOUNT_DIR="$(mktemp -d)"
hdiutil attach "$DMG_PATH" -readonly -nobrowse -mountpoint "$MOUNT_DIR" >/dev/null
test -d "$MOUNT_DIR/$APP_NAME.app"
test -L "$MOUNT_DIR/Applications"
hdiutil detach "$MOUNT_DIR" >/dev/null
rmdir "$MOUNT_DIR"

log "Release artifact"
printf 'path=%s\n' "$DMG_PATH"
printf 'version=%s\n' "$VERSION"
printf 'build=%s\n' "$BUILD_NUMBER"
shasum -a 256 "$DMG_PATH"
