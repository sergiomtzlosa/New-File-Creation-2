#!/bin/bash
# Run the XCTest unit suite against the Debug app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIG:-Debug}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/build/DerivedData}"
LOG="$ROOT/build/test.log"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen is required. Install it with: brew install xcodegen" >&2
    exit 1
fi

cd "$ROOT"
mkdir -p "$ROOT/build"

# xcodebuild does not forward arbitrary shell environment variables to the
# hosted test process. Publish opt-in test destinations through launchd for the
# duration of the run so the test bundle can see them.
NFC_REAL_DESKTOP_ENV_SET=0
NFC_EXTERNAL_VOLUME_ENV_SET=0
cleanup_test_environment() {
    if [ "$NFC_REAL_DESKTOP_ENV_SET" = "1" ]; then
        launchctl unsetenv NFC_TEST_REAL_DESKTOP || true
    fi
    if [ "$NFC_EXTERNAL_VOLUME_ENV_SET" = "1" ]; then
        launchctl unsetenv NFC_TEST_EXTERNAL_VOLUME || true
    fi
}
trap cleanup_test_environment EXIT INT TERM

if [ -n "${NFC_TEST_REAL_DESKTOP:-}" ]; then
    launchctl setenv NFC_TEST_REAL_DESKTOP "$NFC_TEST_REAL_DESKTOP"
    NFC_REAL_DESKTOP_ENV_SET=1
fi
if [ -n "${NFC_TEST_EXTERNAL_VOLUME:-}" ]; then
    launchctl setenv NFC_TEST_EXTERNAL_VOLUME "$NFC_TEST_EXTERNAL_VOLUME"
    NFC_EXTERNAL_VOLUME_ENV_SET=1
fi

xcodegen generate

set +e
xcodebuild \
    -project "$ROOT/NewFileCreation2.xcodeproj" \
    -scheme "NewFileCreation2" \
    -configuration "$CONFIG" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_IDENTITY=- \
    CODE_SIGNING_REQUIRED=YES \
    test 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
set -e

if [ "$status" -ne 0 ]; then
    echo
    echo "Tests failed. Full log: $LOG" >&2
    exit "$status"
fi

grep -E "Executed [0-9]+ tests|TEST SUCCEEDED" "$LOG" | tail -3
echo "Tests passed. Full log: $LOG"
