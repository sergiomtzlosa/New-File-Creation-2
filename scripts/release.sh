#!/bin/bash
# Build, verify, archive, notarize, and package a GitHub Releases + Homebrew cask.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="New File Creation 2.app"
APP="$ROOT/build/$APP_NAME"
HELPER="$APP/Contents/Helpers/nfc"
FINDER="$APP/Contents/PlugIns/New File Creation 2 Finder.appex"
TODAY="$APP/Contents/PlugIns/New File Creation 2 Today.appex"
WIDGET="$APP/Contents/PlugIns/New File Creation 2 Widget.appex"
CASK_TEMPLATE="$ROOT/packaging/homebrew/new-file-creation-2.rb.template"

VERSION="${VERSION:-$(awk '/^[[:space:]]*MARKETING_VERSION:/ { print $2; exit }' "$ROOT/project.yml")}"
VERSION="${VERSION#v}"
GITHUB_REPO="${GITHUB_REPO:-sergiomtzlosa/new-file-creation-2}"
TAP_REPO="${TAP_REPO:-sergiomtzlosa/homebrew-tap}"
IDENTITY="${CODE_SIGN_IDENTITY:--}"
TEAM_ID="${DEVELOPMENT_TEAM:-}"
BUILD_FIRST=1
NOTARIZE=0
PUBLISH=0
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
NOTARY_APPLE_ID="${NOTARY_APPLE_ID:-${APPLE_ID:-}}"
NOTARY_TEAM_ID="${NOTARY_TEAM_ID:-${TEAM_ID}}"
NOTARY_PASSWORD="${NOTARY_PASSWORD:-${APPLE_APP_PASSWORD:-}}"
NOTES_FILE=""
TAP_DIR="${NFC_TAP_DIR:-}"
OUTPUT_DIR="${NFC_RELEASE_DIR:-$ROOT/build/release}"

usage() {
    cat <<'EOF'
Usage: scripts/release.sh [options]

Build a Release app, verify its hardened runtime, create a zip archive, and
generate a Homebrew cask. Signing, notarization, and publishing are opt-in.

Options:
  --version <version>        Release version (default: MARKETING_VERSION)
  --no-build                 Use build/New File Creation 2.app as-is
  --identity <identity>      codesign identity (default: CODE_SIGN_IDENTITY or "-")
  --team-id <team>           Apple Developer team ID (default: DEVELOPMENT_TEAM)
  --notarize                 Submit to Apple and staple the ticket
  --notary-profile <name>    notarytool keychain profile
  --notary-apple-id <email>  Apple ID for notarytool (or NOTARY_APPLE_ID)
  --notary-password <pass>   App-specific password (or NOTARY_PASSWORD)
  --github-repo <owner/repo> GitHub release repository
  --publish                  Create/update the GitHub release with gh
  --notes-file <path>        Release notes for a new GitHub release
  --tap-dir <path>           Copy the generated cask into a tap checkout
  --tap-repo <owner/repo>    Tap repository used in the printed install command
  --output-dir <path>        Output directory (default: build/release)
  -h, --help                 Show this help

Environment:
  CODE_SIGN_IDENTITY, DEVELOPMENT_TEAM, NOTARY_PROFILE,
  NOTARY_APPLE_ID, NOTARY_PASSWORD, GITHUB_REPO, TAP_REPO,
  NFC_RELEASE_DIR, NFC_TAP_DIR

Examples:
  # Local package preview (ad-hoc, no notarization or upload)
  ./scripts/release.sh --no-build

  # Signed and notarized GitHub release
  ./scripts/release.sh \
    --identity "Developer ID Application: Your Name (TEAMID)" \
    --team-id TEAMID --notarize --notary-profile nfc-notary \
    --publish --tap-dir ../homebrew-tap

  # Store notary credentials once
  xcrun notarytool store-credentials nfc-notary \
    --apple-id you@example.com --team-id TEAMID --password app-specific-password
EOF
}

fail() {
    echo "error: $*" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --version)
            [ "$#" -ge 2 ] || fail "--version requires a value"
            VERSION="${2#v}"
            shift 2
            ;;
        --version=*)
            VERSION="${1#*=}"
            VERSION="${VERSION#v}"
            shift
            ;;
        --no-build)
            BUILD_FIRST=0
            shift
            ;;
        --identity)
            [ "$#" -ge 2 ] || fail "--identity requires a value"
            IDENTITY="$2"
            shift 2
            ;;
        --identity=*)
            IDENTITY="${1#*=}"
            shift
            ;;
        --team-id)
            [ "$#" -ge 2 ] || fail "--team-id requires a value"
            TEAM_ID="$2"
            NOTARY_TEAM_ID="${NOTARY_TEAM_ID:-$TEAM_ID}"
            shift 2
            ;;
        --team-id=*)
            TEAM_ID="${1#*=}"
            NOTARY_TEAM_ID="${NOTARY_TEAM_ID:-$TEAM_ID}"
            shift
            ;;
        --notarize)
            NOTARIZE=1
            shift
            ;;
        --notary-profile)
            [ "$#" -ge 2 ] || fail "--notary-profile requires a value"
            NOTARY_PROFILE="$2"
            shift 2
            ;;
        --notary-profile=*)
            NOTARY_PROFILE="${1#*=}"
            shift
            ;;
        --notary-apple-id)
            [ "$#" -ge 2 ] || fail "--notary-apple-id requires a value"
            NOTARY_APPLE_ID="$2"
            shift 2
            ;;
        --notary-apple-id=*)
            NOTARY_APPLE_ID="${1#*=}"
            shift
            ;;
        --notary-password)
            [ "$#" -ge 2 ] || fail "--notary-password requires a value"
            NOTARY_PASSWORD="$2"
            shift 2
            ;;
        --notary-password=*)
            NOTARY_PASSWORD="${1#*=}"
            shift
            ;;
        --github-repo)
            [ "$#" -ge 2 ] || fail "--github-repo requires a value"
            GITHUB_REPO="$2"
            shift 2
            ;;
        --github-repo=*)
            GITHUB_REPO="${1#*=}"
            shift
            ;;
        --publish)
            PUBLISH=1
            shift
            ;;
        --notes-file)
            [ "$#" -ge 2 ] || fail "--notes-file requires a value"
            NOTES_FILE="$2"
            shift 2
            ;;
        --notes-file=*)
            NOTES_FILE="${1#*=}"
            shift
            ;;
        --tap-dir)
            [ "$#" -ge 2 ] || fail "--tap-dir requires a value"
            TAP_DIR="$2"
            shift 2
            ;;
        --tap-dir=*)
            TAP_DIR="${1#*=}"
            shift
            ;;
        --tap-repo)
            [ "$#" -ge 2 ] || fail "--tap-repo requires a value"
            TAP_REPO="$2"
            shift 2
            ;;
        --tap-repo=*)
            TAP_REPO="${1#*=}"
            shift
            ;;
        --output-dir)
            [ "$#" -ge 2 ] || fail "--output-dir requires a value"
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --output-dir=*)
            OUTPUT_DIR="${1#*=}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] \
    || fail "invalid version: $VERSION"
case "$OUTPUT_DIR" in
    /*) ;;
    *) OUTPUT_DIR="$ROOT/$OUTPUT_DIR" ;;
esac
if [ -n "$TAP_DIR" ]; then
    case "$TAP_DIR" in
        /*) ;;
        *) TAP_DIR="$ROOT/$TAP_DIR" ;;
    esac
fi

check_hardened_runtime() {
    # Do not use grep -q here: with pipefail, codesign can receive SIGPIPE and
    # turn a successful match into a failing pipeline.
    codesign -d --verbose=4 "$1" 2>&1 | grep -E 'flags=0x[0-9a-f]+\([^)]*runtime' >/dev/null
}

if [ "$BUILD_FIRST" -eq 1 ]; then
    CODE_SIGN_IDENTITY="$IDENTITY" \
        DEVELOPMENT_TEAM="$TEAM_ID" \
        "$ROOT/scripts/build.sh"
fi

[ -d "$APP" ] || fail "missing $APP; run scripts/build.sh first"
[ -x "$HELPER" ] || fail "missing embedded nfc helper"

APP_VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
[ "$APP_VERSION" = "$VERSION" ] || fail "app version $APP_VERSION does not match requested $VERSION"

codesign --verify --deep --strict "$APP" >/dev/null
codesign --verify --strict "$HELPER"
codesign --verify --strict "$FINDER"
codesign --verify --strict "$TODAY"
codesign --verify --strict "$WIDGET"
for binary in "$APP" "$HELPER" "$FINDER" "$TODAY" "$WIDGET"; do
    check_hardened_runtime "$binary" || fail "hardened runtime is missing from $binary"
done

WIDGET_POINT="$(plutil -extract NSExtension.NSExtensionPointIdentifier raw "$WIDGET/Contents/Info.plist")"
[ "$WIDGET_POINT" = "com.apple.widgetkit-extension" ] \
    || fail "widget does not declare the WidgetKit extension point"
codesign -d --entitlements :- "$WIDGET" 2>/dev/null | grep -q com.apple.security.app-sandbox \
    || fail "widget does not declare the App Sandbox entitlement"

SIGN_INFO="$(codesign -d --verbose=4 "$APP" 2>&1)"
if printf '%s\n' "$SIGN_INFO" | grep -q '^Signature=adhoc$'; then
    ADHOC=1
else
    ADHOC=0
fi
SIGNED_TEAM="$(printf '%s\n' "$SIGN_INFO" | sed -n 's/^TeamIdentifier=//p' | head -n 1)"

if [ "$ADHOC" -eq 0 ]; then
    [ -n "$SIGNED_TEAM" ] && [ "$SIGNED_TEAM" != "not set" ] \
        || fail "the app is not signed with a team; pass --team-id"
    if [ -n "$TEAM_ID" ] && [ "$SIGNED_TEAM" != "$TEAM_ID" ]; then
        fail "signed team $SIGNED_TEAM does not match --team-id $TEAM_ID"
    fi
fi

if [ "$NOTARIZE" -eq 1 ]; then
    [ "$ADHOC" -eq 0 ] || fail "notarization requires a Developer ID Application identity, not an ad-hoc signature"
    if [ -z "$NOTARY_PROFILE" ]; then
        [ -n "$NOTARY_APPLE_ID" ] && [ -n "$NOTARY_TEAM_ID" ] && [ -n "$NOTARY_PASSWORD" ] \
            || fail "set --notary-profile or NOTARY_APPLE_ID, NOTARY_TEAM_ID, and NOTARY_PASSWORD"
    fi
fi

RELEASE_DIR="$OUTPUT_DIR/$VERSION"
ZIP_NAME="New-File-Creation-2-$VERSION.zip"
ZIP="$RELEASE_DIR/$ZIP_NAME"
CASK="$RELEASE_DIR/new-file-creation-2.rb"
mkdir -p "$RELEASE_DIR"
rm -f "$ZIP" "$ZIP.sha256" "$CASK" "$RELEASE_DIR/notarization-$VERSION.log"

echo "Packaging $APP_NAME $VERSION"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

if [ "$NOTARIZE" -eq 1 ]; then
    NOTARY_LOG="$RELEASE_DIR/notarization-$VERSION.log"
    echo "Submitting $ZIP_NAME to the Apple notary service..."
    NOTARY_ARGS=()
    if [ -n "$NOTARY_PROFILE" ]; then
        NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
    else
        NOTARY_ARGS=(--apple-id "$NOTARY_APPLE_ID" --team-id "$NOTARY_TEAM_ID" --password "$NOTARY_PASSWORD")
    fi

    set +e
    xcrun notarytool submit "$ZIP" "${NOTARY_ARGS[@]}" --wait 2>&1 | tee "$NOTARY_LOG"
    NOTARY_STATUS=${PIPESTATUS[0]}
    set -e
    if [ "$NOTARY_STATUS" -ne 0 ] || ! grep -q 'status: Accepted' "$NOTARY_LOG"; then
        SUBMISSION_ID="$(sed -n 's/^[[:space:]]*id: //p' "$NOTARY_LOG" | head -n 1)"
        echo >&2
        echo "Notarization failed. Inspect the log with:" >&2
        if [ -n "$SUBMISSION_ID" ]; then
            echo "  xcrun notarytool log $SUBMISSION_ID ${NOTARY_ARGS[*]}" >&2
        fi
        echo "Full submit output: $NOTARY_LOG" >&2
        exit 1
    fi

    xcrun stapler staple "$APP"
    xcrun stapler validate "$APP"
    spctl --assess --type execute --verbose=2 "$APP"

    # The ticket is stapled to the app, so rebuild the archive after stapling.
    rm -f "$ZIP"
    ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
fi

SHA256="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
printf '%s  %s\n' "$SHA256" "$ZIP_NAME" > "$ZIP.sha256"

URL="https://github.com/$GITHUB_REPO/releases/download/v$VERSION/$ZIP_NAME"
HOMEPAGE="https://github.com/$GITHUB_REPO"
python3 - "$CASK_TEMPLATE" "$CASK" "$VERSION" "$SHA256" "$URL" "$HOMEPAGE" <<'PY'
from pathlib import Path
import sys

template, output, version, sha256, url, homepage = sys.argv[1:]
text = Path(template).read_text(encoding="utf-8")
for key, value in {
    "@@VERSION@@": version,
    "@@SHA256@@": sha256,
    "@@URL@@": url,
    "@@HOMEPAGE@@": homepage,
}.items():
    text = text.replace(key, value)
Path(output).write_text(text, encoding="utf-8")
PY
ruby -c "$CASK" >/dev/null

if [ -n "$TAP_DIR" ]; then
    [ -d "$TAP_DIR" ] || fail "tap checkout not found: $TAP_DIR"
    mkdir -p "$TAP_DIR/Casks"
    cp "$CASK" "$TAP_DIR/Casks/new-file-creation-2.rb"
fi

if [ "$PUBLISH" -eq 1 ]; then
    command -v gh >/dev/null 2>&1 || fail "GitHub CLI is required; install it with: brew install gh"
    gh auth status >/dev/null 2>&1 || fail "GitHub CLI is not authenticated; run: gh auth login"
    TAG="v$VERSION"
    if gh release view "$TAG" --repo "$GITHUB_REPO" >/dev/null 2>&1; then
        echo "Updating GitHub release $TAG on $GITHUB_REPO..."
        gh release upload "$TAG" "$ZIP" "$ZIP.sha256" --repo "$GITHUB_REPO" --clobber
    else
        echo "Creating GitHub release $TAG on $GITHUB_REPO..."
        NOTES_ARGS=(--generate-notes)
        if [ -n "$NOTES_FILE" ]; then
            [ -f "$NOTES_FILE" ] || fail "release notes not found: $NOTES_FILE"
            NOTES_ARGS=(--notes-file "$NOTES_FILE")
        fi
        gh release create "$TAG" "$ZIP" "$ZIP.sha256" \
            --repo "$GITHUB_REPO" \
            --title "New File Creation 2 $VERSION" \
            "${NOTES_ARGS[@]}"
    fi
fi

TAP_USER="${TAP_REPO%%/*}"
echo
echo "Release package:"
echo "  App:     $APP"
echo "  Archive: $ZIP"
echo "  SHA-256: $SHA256"
echo "  Cask:    $CASK"
if [ -n "$TAP_DIR" ]; then
    echo "  Tap:     $TAP_DIR/Casks/new-file-creation-2.rb"
fi
echo
if [ "$ADHOC" -eq 1 ]; then
    echo "Warning: this is an ad-hoc package for local testing; it cannot be notarized."
    echo "Re-run with --identity and --team-id for a distributable release."
    echo
fi
if [ "$NOTARIZE" -eq 0 ]; then
    echo "Notarization was skipped. Add --notarize with a Developer ID identity."
    echo
fi
if [ "$PUBLISH" -eq 0 ]; then
    echo "Upload with:"
    echo "  gh release create v$VERSION \"$ZIP\" \"$ZIP.sha256\" --repo $GITHUB_REPO --title \"New File Creation 2 $VERSION\" --generate-notes"
    echo
fi
if [ -n "$TAP_DIR" ]; then
    echo "Publish the cask from the tap checkout:"
    echo "  git -C \"$TAP_DIR\" add Casks/new-file-creation-2.rb"
    echo "  git -C \"$TAP_DIR\" commit -m \"new-file-creation-2 $VERSION\""
    echo "  git -C \"$TAP_DIR\" push"
    echo
fi
echo "Install from the tap:"
echo "  brew tap $TAP_USER/tap"
echo "  brew install --cask $TAP_USER/tap/new-file-creation-2"
