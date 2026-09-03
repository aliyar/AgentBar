#!/bin/bash
#
# Build (or take an already-built) AgentBar.app and install it into /Applications.
#
#   scripts/install-local.sh            # Release build, ad-hoc sign, install, relaunch
#   scripts/install-local.sh --app PATH # install an existing .app (e.g. from release.sh)
#
# The app is not sandboxed, so there is no container to back up: preferences live in
# ~/Library/Preferences/com.greatpixels.AgentBar.plist and survive a reinstall.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="AgentBar"
DEST="/Applications/$APP_NAME.app"
DERIVED_DATA="$ROOT/build/DerivedData"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
info() { printf '  \033[36m→\033[0m %s\n' "$*"; }
die()  { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }

APP_PATH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --app) shift; APP_PATH="${1:-}" ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done

# 1. Build if no app was supplied
if [ -z "$APP_PATH" ]; then
  info "Building Release..."
  (cd "$ROOT" && xcodegen generate --use-cache --quiet)
  if ! xcodebuild -project "$ROOT/$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration Release \
       -destination 'platform=macOS' -derivedDataPath "$DERIVED_DATA" \
       CODE_SIGNING_ALLOWED=NO build > "$TEMP_DIR/build.log" 2>&1; then
    # `grep` finds nothing on some failures; with pipefail that must not end the script before `die`.
    { grep -E "error:" "$TEMP_DIR/build.log" || tail -15 "$TEMP_DIR/build.log"; } >&2
    cp "$TEMP_DIR/build.log" "$ROOT/build/install-build-failed.log" 2>/dev/null || true
    die "xcodebuild failed (full log: build/install-build-failed.log)"
  fi
  APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
fi
[ -d "$APP_PATH" ] || die "App not found: $APP_PATH"

# 2. Sign — but never re-sign a Developer ID build: re-signing changes the CDHash, and the
# notarization ticket stapled into a released bundle is bound to the old one.
VERSION="$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString)"
BUILD="$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleVersion)"
APP_SIGNATURE="$(codesign -dv --verbose=2 "$APP_PATH" 2>&1 || true)"
case "$APP_SIGNATURE" in
  *"Authority=Developer ID Application"*)
    ok "$APP_NAME $VERSION ($BUILD) is already Developer ID signed; keeping its signature and ticket" ;;
  *)
    # With the Developer ID certificate when this Mac has it: the App Group entitlement
    # is Team-ID-prefixed, and an ad-hoc signature carries no Team ID, so the sandboxed
    # widget could not open the shared container and would show nothing.
    IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
      | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)}"
    SIGN_IDENTITY="${IDENTITY:--}" "$ROOT/scripts/sign-app.sh" "$APP_PATH" >/dev/null || die "codesign failed"
    if [ -n "$IDENTITY" ] && [ "$IDENTITY" != "-" ]; then
      ok "Signed $APP_NAME $VERSION ($BUILD) with $IDENTITY"
    else
      ok "Signed $APP_NAME $VERSION ($BUILD) ad-hoc (no Developer ID certificate: the widget will stay empty)"
    fi ;;
esac

# 3. Replace the app
if pgrep -x "$APP_NAME" >/dev/null; then
  osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5; do pgrep -x "$APP_NAME" >/dev/null || break; sleep 1; done
  pgrep -x "$APP_NAME" >/dev/null && pkill -x "$APP_NAME" || true
  sleep 1
fi
# The widget extension is a separate process that chronod keeps alive; left running, it
# keeps rendering the widgets with the old code after the bundle is replaced.
pkill -f "$DEST/Contents/PlugIns/" 2>/dev/null || true
if [ -d "$DEST" ]; then
  OLD_VERSION="$(defaults read "$DEST/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo '?')"
  rm -rf "$DEST"
  info "Removed previous install (v$OLD_VERSION)"
fi
ditto "$APP_PATH" "$DEST"
xattr -cr "$DEST" 2>/dev/null || true
ok "Installed to $DEST"

# 4. Relaunch
# By path, not by name: LaunchServices would otherwise pick whichever copy ran last (a Debug build, say).
open "$DEST"
sleep 2
pgrep -x "$APP_NAME" >/dev/null && ok "Launched $APP_NAME $VERSION" || die "App did not launch; check Console.app for crash logs"
