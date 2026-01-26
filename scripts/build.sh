#!/bin/bash
# Generate the Xcode project and build the app, Finder extension, and nfc.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIG:-Release}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/build/DerivedData}"
PROJECT="$ROOT/NewFileCreation2.xcodeproj"
SCHEME="NewFileCreation2"
APP_NAME="New File Creation 2.app"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen is required. Install it with: brew install xcodegen" >&2
    exit 1
fi

cd "$ROOT"
xcodegen generate

xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_IDENTITY=- \
    CODE_SIGNING_REQUIRED=YES \
    build

BUILT_APP="$DERIVED_DATA/Build/Products/$CONFIG/$APP_NAME"
if [ ! -d "$BUILT_APP" ]; then
    echo "Build succeeded but the app was not found at: $BUILT_APP" >&2
    exit 1
fi

# Keep a stable, convenient path for the locally distributed app.
PUBLISHED_APP="$ROOT/build/$APP_NAME"
if [ "$CONFIG" = "Release" ]; then
    rm -rf "$PUBLISHED_APP"
    mkdir -p "$ROOT/build"
    ditto "$BUILT_APP" "$PUBLISHED_APP"
    APP="$PUBLISHED_APP"
else
    APP="$BUILT_APP"
fi

codesign --verify --deep --strict "$APP"
if [ ! -x "$APP/Contents/Helpers/nfc" ]; then
    echo "The embedded nfc helper is missing from: $APP" >&2
    exit 1
fi
codesign --verify --strict "$APP/Contents/Helpers/nfc"

echo
echo "Built $CONFIG:"
echo "  $APP"
echo "  $APP/Contents/PlugIns/New File Creation 2 Finder.appex"
echo "  $APP/Contents/Helpers/nfc"
