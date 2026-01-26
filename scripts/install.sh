#!/bin/bash
# Build and install the app into /Applications (or another destination).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="New File Creation 2.app"
DEST_DIR="${NFC_INSTALL_DIR:-/Applications}"
BUILD_FIRST=1
OPEN_AFTER=0
ASSUME_YES=0

usage() {
    cat <<'EOF'
Usage: scripts/install.sh [options]

Options:
  --dest <dir>     Install into <dir> (default: /Applications, or ~/Applications)
  --no-build       Use build/New File Creation 2.app without rebuilding
  --open           Open the app after installing
  --yes            Do not ask before replacing an existing app or quitting it
  -h, --help       Show this help
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dest)
            [ "$#" -ge 2 ] || { echo "--dest requires a directory" >&2; exit 2; }
            DEST_DIR="$2"
            shift 2
            ;;
        --dest=*)
            DEST_DIR="${1#*=}"
            shift
            ;;
        --no-build)
            BUILD_FIRST=0
            shift
            ;;
        --open)
            OPEN_AFTER=1
            shift
            ;;
        --yes|-y)
            ASSUME_YES=1
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

if [ "$BUILD_FIRST" -eq 1 ]; then
    "$ROOT/scripts/build.sh"
fi

SOURCE_APP="$ROOT/build/$APP_NAME"
if [ ! -d "$SOURCE_APP" ]; then
    echo "Missing $SOURCE_APP. Run scripts/build.sh first." >&2
    exit 1
fi

if [ ! -w "$DEST_DIR" ]; then
    if [ "$DEST_DIR" = "/Applications" ]; then
        DEST_DIR="$HOME/Applications"
        echo "/Applications is not writable; installing to $DEST_DIR instead."
    else
        echo "Destination is not writable: $DEST_DIR" >&2
        exit 1
    fi
fi
mkdir -p "$DEST_DIR"
TARGET_APP="$DEST_DIR/$APP_NAME"

if pgrep -x "New File Creation 2" >/dev/null 2>&1; then
    if [ "$ASSUME_YES" -ne 1 ] && [ -t 0 ]; then
        printf "Quit the running app before installing? [Y/n] "
        read -r answer
        case "$answer" in
            [nN]*) echo "Quit the app, then run the installer again." >&2; exit 1 ;;
        esac
    fi
    osascript -e 'tell application id "com.sid.newfilecreation2" to quit' >/dev/null 2>&1 || true
    sleep 1
fi

if [ -e "$TARGET_APP" ] && [ "$ASSUME_YES" -ne 1 ] && [ -t 0 ]; then
    printf "Replace %s? [y/N] " "$TARGET_APP"
    read -r answer
    case "$answer" in
        [yY]*) ;;
        *) echo "Cancelled."; exit 0 ;;
    esac
fi

# Only replace the exact app bundle; user data lives outside the bundle.
case "$TARGET_APP" in
    */"$APP_NAME") ;;
    *) echo "Refusing to replace unexpected path: $TARGET_APP" >&2; exit 1 ;;
esac
rm -rf "$TARGET_APP"
ditto "$SOURCE_APP" "$TARGET_APP"
xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true

codesign --verify --deep --strict "$TARGET_APP"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -f "$TARGET_APP" >/dev/null 2>&1 || true
fi

echo
echo "Installed $TARGET_APP"
echo "Install the command-line tool with:"
echo "  $ROOT/scripts/install-cli.sh --source \"$TARGET_APP\""

if [ "$OPEN_AFTER" -eq 1 ]; then
    open "$TARGET_APP"
fi
