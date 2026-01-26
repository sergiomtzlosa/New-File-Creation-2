#!/bin/bash
# Verify the local release: signing, bundle layout, resources, tests, and CLI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/New File Creation 2.app"
HELPER="$APP/Contents/Helpers/nfc"
EXTENSION="$APP/Contents/PlugIns/New File Creation 2 Finder.appex"
SKIP_BUILD=0
SKIP_TESTS=0

usage() {
    cat <<'EOF'
Usage: scripts/verify.sh [options]

Options:
  --no-build    Verify build/New File Creation 2.app without rebuilding
  --quick       Skip the XCTest and CLI integration suites
  -h, --help    Show this help
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --no-build)
            SKIP_BUILD=1
            shift
            ;;
        --quick)
            SKIP_TESTS=1
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

PASS=0
WARN=0
FAIL=0

check() {
    local label="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "[OK]   $label"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $label"
        FAIL=$((FAIL + 1))
    fi
}

warn() {
    echo "[WARN] $1"
    WARN=$((WARN + 1))
}

if [ "$SKIP_BUILD" -eq 0 ]; then
    "$ROOT/scripts/build.sh"
fi

[ -d "$APP" ] || { echo "Missing $APP. Run scripts/build.sh first." >&2; exit 1; }

check "app signature" codesign --verify --deep --strict "$APP"
check "Finder extension signature" codesign --verify --strict "$EXTENSION"
check "nfc signature" codesign --verify --strict "$HELPER"
check "nfc is executable" test -x "$HELPER"
check "Finder extension embedded" test -d "$EXTENSION"
check "Info.plist syntax" plutil -lint "$APP/Contents/Info.plist"
check "Finder Info.plist syntax" plutil -lint "$EXTENSION/Contents/Info.plist"

VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
check "version is 2.0.0" test "$VERSION" = "2.0.0"

BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "$APP/Contents/Info.plist")"
check "app bundle identifier" test "$BUNDLE_ID" = "com.sid.newfilecreation2"

EXT_BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "$EXTENSION/Contents/Info.plist")"
check "extension bundle identifier" test "$EXT_BUNDLE_ID" = "com.sid.newfilecreation2.finder"

PRINCIPAL="$(plutil -extract NSExtension.NSExtensionPrincipalClass raw "$EXTENSION/Contents/Info.plist")"
check "Finder Sync principal class" test "$PRINCIPAL" = "NFCFinderSync"

SCHEME="$(plutil -extract 'CFBundleURLTypes.0.CFBundleURLSchemes.0' raw "$APP/Contents/Info.plist")"
check "URL scheme" test "$SCHEME" = "newfilecreation2"

check "English localization" test -f "$APP/Contents/Resources/en.lproj/Localizable.strings"
check "Spanish localization" test -f "$APP/Contents/Resources/es.lproj/Localizable.strings"
check "Finder English localization" test -f "$EXTENSION/Contents/Resources/en.lproj/Localizable.strings"
check "Finder Spanish localization" test -f "$EXTENSION/Contents/Resources/es.lproj/Localizable.strings"

check_localization() {
    local tmp
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/nfc-l10n.XXXXXX")"
    plutil -convert json -o "$tmp/en.json" "$APP/Contents/Resources/en.lproj/Localizable.strings"
    plutil -convert json -o "$tmp/es.json" "$APP/Contents/Resources/es.lproj/Localizable.strings"
    python3 - "$tmp/en.json" "$tmp/es.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    english = json.load(handle)
with open(sys.argv[2], encoding="utf-8") as handle:
    spanish = json.load(handle)
if set(english) != set(spanish):
    raise SystemExit("localization keys differ")
if any(not value for value in english.values()) or any(not value for value in spanish.values()):
    raise SystemExit("a localization value is empty")
PY
    local status=$?
    rm -rf "$tmp"
    return "$status"
}
check "localization key parity" check_localization

check "bundled templates present" test "$(find "$APP/Contents/Resources/Templates" -maxdepth 1 -type f | wc -l | tr -d ' ')" -ge 30
check "app icon present" test -f "$APP/Contents/Resources/AppIcon.icns"

if [ "$SKIP_TESTS" -eq 0 ]; then
    "$ROOT/scripts/test.sh"
    PASS=$((PASS + 1))
    "$ROOT/scripts/test-cli.sh"
    PASS=$((PASS + 1))
fi

PLUGIN_OUTPUT="$(/usr/bin/pluginkit -m -i com.sid.newfilecreation2.finder 2>/dev/null || true)"
if [ -z "$PLUGIN_OUTPUT" ]; then
    warn "Finder extension is not registered yet (open the app once)."
elif printf '%s' "$PLUGIN_OUTPUT" | grep -q '^+'; then
    echo "[OK]   Finder extension is enabled"
    PASS=$((PASS + 1))
else
    warn "Finder extension is registered but not enabled."
fi

echo
echo "Verification: $PASS passed, $WARN warnings, $FAIL failures."
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
