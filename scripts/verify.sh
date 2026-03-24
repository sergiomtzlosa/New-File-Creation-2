#!/bin/bash
# Verify the local release: signing, bundle layout, resources, tests, and CLI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/New File Creation 2.app"
HELPER="$APP/Contents/Helpers/nfc"
EXTENSION="$APP/Contents/PlugIns/New File Creation 2 Finder.appex"
TODAY="$APP/Contents/PlugIns/New File Creation 2 Today.appex"
SKIP_BUILD=0
SKIP_TESTS=0

# Every language that shipped with New File Creation v1, plus English.
LANGUAGES=(ar ca da de el en es eu-ES fi fr gl hi id is-IS it ja ko ms nb nl pl pt-PT ro ru sv tr zh-Hans zh-Hant)

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
check "Today extension signature" codesign --verify --strict "$TODAY"
check "nfc signature" codesign --verify --strict "$HELPER"
check "nfc is executable" test -x "$HELPER"
check "Finder extension embedded" test -d "$EXTENSION"
check "Today extension embedded" test -d "$TODAY"
check "Info.plist syntax" plutil -lint "$APP/Contents/Info.plist"
check "Finder Info.plist syntax" plutil -lint "$EXTENSION/Contents/Info.plist"
check "Today Info.plist syntax" plutil -lint "$TODAY/Contents/Info.plist"

VERSION="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
check "version is 2.0.0" test "$VERSION" = "2.0.0"

BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "$APP/Contents/Info.plist")"
check "app bundle identifier" test "$BUNDLE_ID" = "com.sid.newfilecreation2"

EXT_BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "$EXTENSION/Contents/Info.plist")"
check "extension bundle identifier" test "$EXT_BUNDLE_ID" = "com.sid.newfilecreation2.finder"

TODAY_BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "$TODAY/Contents/Info.plist")"
check "Today bundle identifier" test "$TODAY_BUNDLE_ID" = "com.sid.newfilecreation2.today"

PRINCIPAL="$(plutil -extract NSExtension.NSExtensionPrincipalClass raw "$EXTENSION/Contents/Info.plist")"
check "Finder Sync principal class" test "$PRINCIPAL" = "NFCFinderSync"

SCHEME="$(plutil -extract 'CFBundleURLTypes.0.CFBundleURLSchemes.0' raw "$APP/Contents/Info.plist")"
check "URL scheme" test "$SCHEME" = "newfilecreation2"

check "English localization" test -f "$APP/Contents/Resources/en.lproj/Localizable.strings"

check_all_localizations() {
    local bundle="$1"
    local lang
    for lang in "${LANGUAGES[@]}"; do
        [ -f "$bundle/Contents/Resources/$lang.lproj/Localizable.strings" ] || return 1
    done
}
check "app localization files (28 languages)" check_all_localizations "$APP"
check "Finder localization files (28 languages)" check_all_localizations "$EXTENSION"
check "Today localization files (28 languages)" check_all_localizations "$TODAY"

check_localization() {
    python3 - "$APP/Contents/Resources" "$EXTENSION/Contents/Resources" "$TODAY/Contents/Resources" <<'PY'
import json
import re
import subprocess
import sys
from pathlib import Path

languages = "ar ca da de el en es eu-ES fi fr gl hi id is-IS it ja ko ms nb nl pl pt-PT ro ru sv tr zh-Hans zh-Hant".split()
product = "New File Creation 2"
placeholder = re.compile(r"%(?:\d+\$)?[-+#0-9.]*[a-zA-Z@%]")


def load(path):
    result = subprocess.run(
        ["plutil", "-convert", "json", "-o", "-", str(path)],
        capture_output=True, check=True)
    return json.loads(result.stdout)


for resources in sys.argv[1:]:
    base = Path(resources)
    english = load(base / "en.lproj/Localizable.strings")
    if any(not value for value in english.values()):
        raise SystemExit(f"{base}: empty English value")
    for language in languages:
        if language == "en":
            continue
        translated = load(base / f"{language}.lproj/Localizable.strings")
        if set(english) != set(translated):
            raise SystemExit(f"{base}/{language}: localization keys differ")
        for key, value in english.items():
            text = translated[key]
            if not text:
                raise SystemExit(f"{base}/{language}: empty value for {key!r}")
            if sorted(placeholder.findall(value)) != sorted(placeholder.findall(text)):
                raise SystemExit(f"{base}/{language}: placeholders differ for {key!r}")
            if product in value and product not in text:
                raise SystemExit(f"{base}/{language}: product name missing for {key!r}")
PY
}
check "localization parity, placeholders, product name" check_localization

check "Finder sandbox entitlement" bash -c "codesign -d --entitlements :- '$EXTENSION' 2>/dev/null | grep -q com.apple.security.app-sandbox"
check "Today sandbox entitlement" bash -c "codesign -d --entitlements :- '$TODAY' 2>/dev/null | grep -q com.apple.security.app-sandbox"

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
