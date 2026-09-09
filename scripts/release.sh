#!/bin/bash
#
# AgentBar release pipeline.
#
#   scripts/release.sh <X.Y.Z> [options]
#
# What it does, in order:
#   1. Pre-flight checks (clean tree on main, tools, Sparkle key, notary profile, changelog notes)
#   2. Bumps MARKETING_VERSION / CURRENT_PROJECT_VERSION in project.yml, regenerates the project
#   3. Moves the "Unreleased" section of CHANGELOG.md under the new version
#   4. Builds Release, signs it (scripts/sign-app.sh with the Developer ID certificate)
#   5. Zips it (with install.txt) into dist/, notarizes the zip and staples the ticket
#   6. Uploads the zip to the download host (scripts/upload-r2.sh); if that is not set up,
#      commits it under site/public/releases/ instead (fallback, see docs/RELEASING.md)
#   7. Signs the zip with the Sparkle EdDSA key (Keychain account "agentbar"), prepends an
#      item to site/public/appcast.xml, points the site at the new version, builds the site
#   8. Commits "Release X.Y.Z", tags vX.Y.Z, pushes, creates the GitHub release (notes only:
#      the zip lives on the download host, so an update never depends on a release asset)
#
# Options:
#   --dry-run      Do steps 1, 4 and 5 into dist/; change nothing in the repo, R2 or GitHub
#   --no-publish   Commit and tag locally, but do not push or create the GitHub release
#   --allow-dirty  Skip the clean-working-tree check
#   --notes FILE   Use FILE as release notes instead of CHANGELOG.md's Unreleased section
#   --adhoc        Force ad-hoc signing (no notarization) even if a certificate is installed
#
# Environment:
#   NOTARY_PROFILE  notarytool keychain profile (default: the name in .notary-profile, gitignored)
#   SIGN_IDENTITY   codesign identity to use instead of the auto-detected Developer ID
#   R2_BUCKET       Cloudflare R2 bucket for scripts/upload-r2.sh (unset → site fallback)
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP_NAME="AgentBar"
SCHEME="AgentBar"
REPO="${REPO:-aliyar/AgentBar}"
CHANGELOG="$ROOT/CHANGELOG.md"
SITE_DIR="$ROOT/site"
APPCAST="$SITE_DIR/public/appcast.xml"
APPCAST_URL="https://agentbar.greatpixels.com/appcast.xml"
DOWNLOAD_HOST="https://dl.greatpixels.com/agentbar"
FALLBACK_RELEASES_DIR="$SITE_DIR/public/releases"
SITE_VERSION_FILE="$SITE_DIR/app/release.ts"
INSTALL_TEMPLATE="$ROOT/scripts/install.template.txt"
DIST="$ROOT/dist"
DERIVED_DATA="$ROOT/build/DerivedData"
SPARKLE_ACCOUNT="agentbar"          # Keychain account holding the EdDSA private key; never omit --account
SPARKLE_BIN="${SPARKLE_BIN:-$DERIVED_DATA/SourcePackages/artifacts/sparkle/Sparkle/bin}"
NOTARY_PROFILE="${NOTARY_PROFILE:-$(cat "$ROOT/.notary-profile" 2>/dev/null | head -1 | xargs || true)}"
RELEASE_BRANCH="main"

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
info()  { printf '  \033[36m→\033[0m %s\n' "$*"; }
ok()    { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn()  { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()   { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }
step()  { echo; bold "[$1] $2"; }
usage() { sed -n '2,32p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

yml_value() { sed -n "s/^ *$1: \"\([^\"]*\)\".*/\1/p" project.yml | head -1; }

# Print the body of the "## [Unreleased]" section of CHANGELOG.md (without the heading).
unreleased_notes() {
  [ -f "$CHANGELOG" ] || return 0
  awk '/^## \[Unreleased\]/ { grab = 1; next } /^## / { if (grab) exit } grab { print }' "$CHANGELOG" \
    | sed '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
}

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
VERSION=""; DRY_RUN=0; PUBLISH=1; ALLOW_DIRTY=0; NOTES_FILE=""; FORCE_ADHOC=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)     usage 0 ;;
    --dry-run)     DRY_RUN=1 ;;
    --no-publish)  PUBLISH=0 ;;
    --allow-dirty) ALLOW_DIRTY=1 ;;
    --adhoc)       FORCE_ADHOC=1 ;;
    --notes)       shift; NOTES_FILE="${1:-}"; [ -f "$NOTES_FILE" ] || die "--notes file not found: $NOTES_FILE" ;;
    -*)            die "Unknown option: $1" ;;
    *)             [ -z "$VERSION" ] && VERSION="$1" || die "Unexpected argument: $1" ;;
  esac
  shift
done
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || usage 1

# ---------------------------------------------------------------------------
# 1. Pre-flight
# ---------------------------------------------------------------------------
step "1/8" "Pre-flight checks"
for tool in xcodegen xcodebuild gh ditto plutil codesign python3 xmllint npm; do
  command -v "$tool" >/dev/null || die "$tool is required"
done
[ -x "$ROOT/scripts/sign-app.sh" ] || die "scripts/sign-app.sh missing or not executable"

xcodegen generate --use-cache --quiet
if [ ! -x "$SPARKLE_BIN/sign_update" ]; then
  info "Resolving Swift packages to fetch the Sparkle tools..."
  xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$SCHEME" -derivedDataPath "$DERIVED_DATA" -resolvePackageDependencies -quiet
fi
[ -x "$SPARKLE_BIN/sign_update" ] || die "Sparkle sign_update not found at $SPARKLE_BIN (set SPARKLE_BIN)"
PROBE="$TEMP_DIR/probe.bin"; echo probe > "$PROBE"
"$SPARKLE_BIN/sign_update" --account "$SPARKLE_ACCOUNT" "$PROBE" >/dev/null 2>&1 \
  || die "Sparkle EdDSA key for account '$SPARKLE_ACCOUNT' not found in the Keychain. Generate it once with: $SPARKLE_BIN/generate_keys --account $SPARKLE_ACCOUNT"
PLIST_PUBKEY="$(sed -n 's/^ *SUPublicEDKey: "\([^"]*\)".*/\1/p' project.yml | head -1)"
KEYCHAIN_PUBKEY="$("$SPARKLE_BIN/generate_keys" --account "$SPARKLE_ACCOUNT" -p 2>/dev/null || true)"
[ -n "$PLIST_PUBKEY" ] || die "SUPublicEDKey is empty in project.yml; paste the output of: $SPARKLE_BIN/generate_keys --account $SPARKLE_ACCOUNT -p"
[ -z "$KEYCHAIN_PUBKEY" ] || [ "$PLIST_PUBKEY" = "$KEYCHAIN_PUBKEY" ] \
  || die "SUPublicEDKey in project.yml ($PLIST_PUBKEY) does not match the Keychain key ($KEYCHAIN_PUBKEY)"

SIGN_IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null \
  | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)}"
if [ "$FORCE_ADHOC" -eq 0 ] && [ -n "$SIGN_IDENTITY" ] && [ "$SIGN_IDENTITY" != "-" ]; then
  NOTARIZE=1
  [ -n "$NOTARY_PROFILE" ] || die "No notarytool profile. Put its name in $ROOT/.notary-profile (gitignored) or pass NOTARY_PROFILE=…
    To create one: xcrun notarytool store-credentials <name> --apple-id <apple-id> --team-id <team-id>"
  xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || die "notarytool profile '$NOTARY_PROFILE' is missing or invalid"
else
  SIGN_IDENTITY="-"; NOTARIZE=0
  warn "Signing ad-hoc: the release will NOT be notarized and macOS will refuse the download on first launch."
fi

if [ "$DRY_RUN" -eq 0 ]; then
  [ "$(git branch --show-current)" = "$RELEASE_BRANCH" ] || die "Releases are cut from '$RELEASE_BRANCH'"
  if [ "$ALLOW_DIRTY" -eq 0 ] && [ -n "$(git status --porcelain)" ]; then
    die "Working tree has uncommitted changes. Commit them first (or pass --allow-dirty)."
  fi
  [ "$PUBLISH" -eq 0 ] || gh auth status >/dev/null 2>&1 || die "gh is not authenticated (run: gh auth login)"
fi

OLD_VERSION="$(yml_value MARKETING_VERSION)"
OLD_BUILD="$(yml_value CURRENT_PROJECT_VERSION)"
[ -n "$OLD_VERSION" ] || die "Could not read MARKETING_VERSION from project.yml"
NEW_BUILD=$(( ${OLD_BUILD:-0} + 1 ))
TAG="v$VERSION"
ZIP_NAME="$APP_NAME-$VERSION.zip"
ZIP_PATH="$DIST/$ZIP_NAME"
MIN_MACOS="$(sed -n 's/^ *macOS: "\([^"]*\)".*/\1/p' project.yml | head -1)"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "Tag $TAG already exists"

if [ -n "$NOTES_FILE" ]; then NOTES="$(cat "$NOTES_FILE")"; else NOTES="$(unreleased_notes)"; fi
[ -n "$(echo "$NOTES" | tr -d '[:space:]')" ] || die "CHANGELOG.md has no entries under '## [Unreleased]' (or pass --notes FILE)"

ok "Version: $OLD_VERSION (build $OLD_BUILD) → $VERSION (build $NEW_BUILD), tag $TAG, asset $ZIP_NAME"
ok "Sparkle: key '$SPARKLE_ACCOUNT' present, public key matches project.yml"
[ "$NOTARIZE" -eq 1 ] && ok "Signing: $SIGN_IDENTITY (notarizing with profile '$NOTARY_PROFILE')" || ok "Signing: ad-hoc"
echo; bold "  Release notes:"; echo "$NOTES" | sed 's/^/    /'
[ "$DRY_RUN" -eq 0 ] || { echo; warn "Dry run: the repository will not be modified."; }

# ---------------------------------------------------------------------------
# 2. Version bump (reverted at exit on a dry run)
# ---------------------------------------------------------------------------
step "2/8" "Bump version in project.yml"
cp project.yml "$TEMP_DIR/project.yml.before"
restore_version() { cp "$TEMP_DIR/project.yml.before" project.yml; xcodegen generate --use-cache --quiet; }
[ "$DRY_RUN" -eq 0 ] || trap 'restore_version; rm -rf "$TEMP_DIR"' EXIT
sed -i '' "s/^\( *MARKETING_VERSION: \)\"[^\"]*\"/\1\"$VERSION\"/" project.yml
sed -i '' "s/^\( *CURRENT_PROJECT_VERSION: \)\"[^\"]*\"/\1\"$NEW_BUILD\"/" project.yml
grep -q "MARKETING_VERSION: \"$VERSION\"" project.yml || die "could not set MARKETING_VERSION in project.yml"
xcodegen generate --use-cache --quiet
ok "MARKETING_VERSION = $VERSION, CURRENT_PROJECT_VERSION = $NEW_BUILD"

# ---------------------------------------------------------------------------
# 3. Changelog
# ---------------------------------------------------------------------------
step "3/8" "Update CHANGELOG.md"
if [ "$DRY_RUN" -eq 0 ] && [ -z "$NOTES_FILE" ] && [ -f "$CHANGELOG" ]; then
  TODAY="$(date -u +%Y-%m-%d)"
  awk -v ver="$VERSION" -v date="$TODAY" '
    /^## \[Unreleased\]/ && !done { print; print ""; print "## [" ver "] - " date; done = 1; next }
    { print }
  ' "$CHANGELOG" > "$TEMP_DIR/CHANGELOG.md" && mv "$TEMP_DIR/CHANGELOG.md" "$CHANGELOG"
  REPO_URL="https://github.com/$REPO"
  if grep -q '^\[Unreleased\]: ' "$CHANGELOG"; then
    sed -i '' -E "s#^\[Unreleased\]: .*#[Unreleased]: $REPO_URL/compare/$TAG...HEAD#" "$CHANGELOG"
    grep -q "^\[$VERSION\]: " "$CHANGELOG" || printf '[%s]: %s/releases/tag/%s\n' "$VERSION" "$REPO_URL" "$TAG" >> "$CHANGELOG"
  fi
  ok "Moved Unreleased notes under [$VERSION] - $TODAY"
else
  info "(skipped)"
fi

# ---------------------------------------------------------------------------
# 4. Build + sign
# ---------------------------------------------------------------------------
step "4/8" "Build Release and sign"
BUILD_LOG="$TEMP_DIR/build.log"
rm -rf "$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
if ! xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$SCHEME" -configuration Release \
     -destination 'platform=macOS' -derivedDataPath "$DERIVED_DATA" \
     CODE_SIGNING_ALLOWED=NO build > "$BUILD_LOG" 2>&1; then
  grep -E "error:" "$BUILD_LOG" | head -20 >&2
  cp "$BUILD_LOG" "$ROOT/build/release-build-failed.log" 2>/dev/null || true
  die "xcodebuild failed (full log: build/release-build-failed.log)"
fi
APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
[ -d "$APP_PATH" ] || die "Build did not produce $APP_NAME.app"
# Xcode did not sign (CODE_SIGNING_ALLOWED=NO); sign-app.sh signs the Sparkle components
# individually, then the app with its entitlements, hardened runtime and timestamp.
SIGN_IDENTITY="$SIGN_IDENTITY" "$ROOT/scripts/sign-app.sh" "$APP_PATH" || die "codesign failed"
BUILT_VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP_PATH/Contents/Info.plist")"
[ "$BUILT_VERSION" = "$VERSION" ] || die "Built app reports $BUILT_VERSION, expected $VERSION"
[ -d "$APP_PATH/Contents/Frameworks/Sparkle.framework" ] || die "Sparkle.framework is not embedded"
ok "Built and signed $APP_NAME $BUILT_VERSION (build $NEW_BUILD)"

# ---------------------------------------------------------------------------
# 5. Package, notarize, staple
# ---------------------------------------------------------------------------
step "5/8" "Package zip, notarize and staple"
rm -rf "$DIST"; mkdir -p "$DIST"
STAGE_DIR="$TEMP_DIR/stage"; mkdir -p "$STAGE_DIR"
ditto "$APP_PATH" "$STAGE_DIR/$APP_NAME.app"
sed -e "s/{{VERSION}}/$VERSION/g" -e "s/{{MIN_MACOS}}/$MIN_MACOS/g" "$INSTALL_TEMPLATE" > "$STAGE_DIR/install.txt"
cp "$STAGE_DIR/install.txt" "$DIST/install.txt"
ditto -c -k --sequesterRsrc "$STAGE_DIR" "$ZIP_PATH"

if [ "$NOTARIZE" -eq 1 ]; then
  info "Submitting to Apple for notarization (usually a few minutes)…"
  NOTARY_JSON="$DIST/.notary.json"
  # notarytool exits 0 even when Apple rejects the submission, so read the status, not $?.
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait \
    --output-format json > "$NOTARY_JSON" 2>"$TEMP_DIR/notary.err" || true
  NOTARY_STATUS="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("status",""))' "$NOTARY_JSON" 2>/dev/null || true)"
  NOTARY_ID="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("id",""))' "$NOTARY_JSON" 2>/dev/null || true)"
  [ "$NOTARY_STATUS" = "Accepted" ] || { head -5 "$TEMP_DIR/notary.err" >&2 || true
    die "Notarization ${NOTARY_STATUS:-failed}. Details: xcrun notarytool log ${NOTARY_ID:-<id>} --keychain-profile $NOTARY_PROFILE"; }
  ok "Notarized by Apple (submission $NOTARY_ID)"
  # Staple, then rebuild the zip: everything derived from it (EdDSA signature, length) must
  # describe the file people actually download.
  xcrun stapler staple "$STAGE_DIR/$APP_NAME.app" >/dev/null || die "stapler staple failed"
  xcrun stapler validate "$STAGE_DIR/$APP_NAME.app" >/dev/null || die "stapler validate failed"
  rm -f "$ZIP_PATH"; ditto -c -k --sequesterRsrc "$STAGE_DIR" "$ZIP_PATH"
  ok "Stapled the notarization ticket and repackaged the zip"
fi
ZIP_SIZE="$(stat -f%z "$ZIP_PATH")"
ok "$ZIP_NAME ($(du -h "$ZIP_PATH" | cut -f1))"

if [ "$DRY_RUN" -eq 1 ]; then
  echo; ok "Dry run complete: artifacts in dist/, nothing else changed."; exit 0
fi

# ---------------------------------------------------------------------------
# 6. Upload
# ---------------------------------------------------------------------------
step "6/8" "Upload the zip"
if [ -n "${R2_BUCKET:-}" ]; then
  DOWNLOAD_URL="$("$ROOT/scripts/upload-r2.sh" "$ZIP_PATH" | tail -1)"
  ok "Uploaded to $DOWNLOAD_URL"
else
  # Fallback: commit the zip into the site, as Great Menubar does. Move to R2 before the second
  # release — every zip committed here stays in git history forever.
  warn "R2_BUCKET not set: committing the zip under site/public/releases/ instead"
  mkdir -p "$FALLBACK_RELEASES_DIR"
  for old in "$FALLBACK_RELEASES_DIR"/$APP_NAME-*.zip; do [ -e "$old" ] && git rm -q --cached "$old" 2>/dev/null; rm -f "$old"; done
  cp "$ZIP_PATH" "$FALLBACK_RELEASES_DIR/$ZIP_NAME"
  # The repository ignores *.zip; the release zips are the one exception (.gitignore), and
  # -f makes sure of it either way.
  git add -f "$FALLBACK_RELEASES_DIR/$ZIP_NAME"
  DOWNLOAD_URL="${APPCAST_URL%/appcast.xml}/releases/$ZIP_NAME"
  ok "Zip staged at $DOWNLOAD_URL"
fi

# ---------------------------------------------------------------------------
# 7. Sparkle appcast + site
# ---------------------------------------------------------------------------
step "7/8" "Sign for Sparkle, update appcast and site"
ED_ATTRS="$("$SPARKLE_BIN/sign_update" --account "$SPARKLE_ACCOUNT" "$ZIP_PATH")"
ED_SIGNATURE="$(echo "$ED_ATTRS" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')"
[ -n "$ED_SIGNATURE" ] || die "sign_update did not return an EdDSA signature"

NOTES_TMP="$TEMP_DIR/notes.txt"; printf '%s\n' "$NOTES" > "$NOTES_TMP"
python3 - "$APPCAST" "$APP_NAME" "$VERSION" "$NEW_BUILD" "$MIN_MACOS" "$DOWNLOAD_URL" "$ZIP_SIZE" "$ED_SIGNATURE" "$APPCAST_URL" "$NOTES_TMP" <<'PY'
import html, re, sys
from datetime import datetime, timezone
appcast, app, version, build, min_macos, url, size, sig, feed_url, notes_path = sys.argv[1:11]
notes_md = open(notes_path, encoding="utf-8").read()

# Minimal Markdown → HTML for the release notes (headings, bullets, inline code, bold).
# A bullet wrapped over several lines is one bullet: the continuation lines are folded
# into it rather than each becoming a paragraph of its own, which broke every entry in
# the changelog that ran past one line.
def inline(t):
    t = html.escape(t)
    t = re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
    return re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", t)

blocks, bullet, paragraph = [], None, None
def close_bullet():
    global bullet
    if bullet is not None: blocks.append(("li", " ".join(bullet))); bullet = None
def close_paragraph():
    global paragraph
    if paragraph is not None: blocks.append(("p", " ".join(paragraph))); paragraph = None

for line in notes_md.splitlines():
    s = line.strip()
    if not s:
        close_bullet(); close_paragraph(); continue
    if s.startswith(("- ", "* ")):
        close_bullet(); close_paragraph(); bullet = [s[2:]]; continue
    if s.startswith(("### ", "## ")):
        close_bullet(); close_paragraph()
        level, text = ("h3", s[4:]) if s.startswith("### ") else ("h2", s[3:])
        blocks.append((level, text)); continue
    # A line under a bullet continues it; anywhere else it is prose.
    if bullet is not None: bullet.append(s)
    elif paragraph is not None: paragraph.append(s)
    else: paragraph = [s]
close_bullet(); close_paragraph()

out, in_list = [], False
for kind, text in blocks:
    if kind == "li":
        if not in_list: out.append("<ul>"); in_list = True
        out.append(f"<li>{inline(text)}</li>"); continue
    if in_list: out.append("</ul>"); in_list = False
    out.append(f"<{kind}>{inline(text)}</{kind}>")
if in_list: out.append("</ul>")
description = "\n".join(out)

pub_date = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")
item = f"""    <item>
      <title>{app} {version}</title>
      <pubDate>{pub_date}</pubDate>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{min_macos}</sparkle:minimumSystemVersion>
      <description><![CDATA[
{description}
      ]]></description>
      <enclosure url="{url}" length="{size}" type="application/octet-stream" sparkle:edSignature="{sig}"/>
    </item>"""

# Keep the previous items (max 5 total) so Sparkle can show notes for skipped versions.
old_items = []
try:
    old = open(appcast, encoding="utf-8").read()
    old_items = [m for m in re.findall(r"    <item>.*?</item>", old, flags=re.S)
                 if f"<sparkle:version>{build}</sparkle:version>" not in m]
except FileNotFoundError:
    pass
items = "\n".join([item] + old_items[:4])
open(appcast, "w", encoding="utf-8").write(f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>{app}</title>
    <link>{feed_url}</link>
    <description>Updates for {app}</description>
    <language>en</language>
{items}
  </channel>
</rss>
""")
PY
xmllint --noout "$APPCAST" || die "Generated appcast.xml is not well-formed XML"
ok "appcast.xml → $VERSION (build $NEW_BUILD), enclosure $DOWNLOAD_URL"

# The site states the version, the download link and the size in exactly one file.
cat > "$SITE_VERSION_FILE" <<TS
// Written by scripts/release.sh. Do not edit by hand.
export const release = {
  version: "$VERSION",
  date: "$(date -u +%Y-%m-%d)",
  url: "$DOWNLOAD_URL",
  size: "$(python3 -c "print(f'{$ZIP_SIZE/1024/1024:.1f} MB')")",
  minMacOS: "$MIN_MACOS",
} as const;
TS
( cd "$SITE_DIR" && { [ -d node_modules ] || npm ci --silent; } && npm run build --silent ) >/dev/null
ok "Site builds with $VERSION"

# ---------------------------------------------------------------------------
# 8. Commit, tag, publish
# ---------------------------------------------------------------------------
step "8/8" "Commit, tag, publish"
git add project.yml "$CHANGELOG" "$APPCAST" "$SITE_VERSION_FILE"
[ -d "$FALLBACK_RELEASES_DIR" ] && git add -A "$FALLBACK_RELEASES_DIR"
git commit -q -m "Release $VERSION" -m "$NOTES"
git tag -a "$TAG" -m "$APP_NAME $TAG" -m "$NOTES"
ok "Committed $(git rev-parse --short HEAD), tagged $TAG"

if [ "$PUBLISH" -eq 1 ]; then
  git push -q origin "refs/heads/$RELEASE_BRANCH" "refs/tags/$TAG"
  BODY_FILE="$TEMP_DIR/notes.md"
  {
    echo "## $APP_NAME $TAG"; echo; echo "$NOTES"; echo
    echo "Download: $DOWNLOAD_URL"; echo
    echo "Requires macOS $MIN_MACOS or later. Installed copies update themselves through **Check for Updates…**."
  } > "$BODY_FILE"
  gh release create "$TAG" --repo "$REPO" --title "$APP_NAME $VERSION" --notes-file "$BODY_FILE" >/dev/null
  ok "Pushed $RELEASE_BRANCH and $TAG; GitHub release created (notes only)"
  echo; ok "Render redeploys the site on push: $APPCAST_URL will serve $VERSION in a few minutes."
else
  warn "Not published (--no-publish). To publish:"
  echo "    git push origin $RELEASE_BRANCH refs/tags/$TAG && gh release create $TAG --repo $REPO --title \"$APP_NAME $VERSION\" --notes-file <notes>"
fi
