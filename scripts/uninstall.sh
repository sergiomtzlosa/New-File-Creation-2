#!/bin/bash
# Remove the app and its command-line links. User templates are kept by default.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="New File Creation 2.app"
DEST_DIR="${NFC_INSTALL_DIR:-/Applications}"
ASSUME_YES=0
REMOVE_DATA=0
PREFIX="${XDG_BIN_HOME:-$HOME/.local/bin}"

usage() {
    cat <<'EOF'
Usage: scripts/uninstall.sh [options]

Options:
  --dest <dir>     Look for the app in <dir> (default: /Applications)
  --prefix <dir>   Remove the nfc link from <dir> (default: ~/.local/bin)
  --remove-data    Also move the support folder (config and templates) to Trash
  --yes            Do not ask for confirmation
  -h, --help       Show this help

The app is moved to Trash. Template files are never deleted.
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
        --prefix)
            [ "$#" -ge 2 ] || { echo "--prefix requires a directory" >&2; exit 2; }
            PREFIX="$2"
            shift 2
            ;;
        --prefix=*)
            PREFIX="${1#*=}"
            shift
            ;;
        --remove-data)
            REMOVE_DATA=1
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

PREFIX="${PREFIX/#\~/$HOME}"

if pgrep -x "New File Creation 2" >/dev/null 2>&1; then
    if [ "$ASSUME_YES" -ne 1 ] && [ -t 0 ]; then
        printf "Quit the running app before uninstalling? [Y/n] "
        read -r answer
        case "$answer" in
            [nN]*) echo "Quit the app, then run the uninstaller again." >&2; exit 1 ;;
        esac
    fi
    osascript -e 'tell application id "com.sid.newfilecreation2" to quit' >/dev/null 2>&1 || true
    sleep 1
fi

if [ "$ASSUME_YES" -ne 1 ] && [ -t 0 ]; then
    printf "Move %s to Trash? [y/N] " "$DEST_DIR/$APP_NAME"
    read -r answer
    case "$answer" in
        [yY]*) ;;
        *) echo "Cancelled."; exit 0 ;;
    esac
fi

trash_path() {
    local source="$1"
    [ -e "$source" ] || return 0
    local trash="$HOME/.Trash"
    mkdir -p "$trash"
    local name
    name="$(basename "$source")"
    local destination="$trash/$name"
    if [ -e "$destination" ]; then
        destination="$trash/${name%.*}-$(date +%Y%m%d-%H%M%S).${name##*.}"
    fi
    mv "$source" "$destination"
    echo "Moved $source to $destination"
}

"$ROOT/scripts/install-cli.sh" --prefix "$PREFIX" --uninstall >/dev/null 2>&1 || true

APP="$DEST_DIR/$APP_NAME"
case "$APP" in
    */"$APP_NAME") trash_path "$APP" ;;
    *) echo "Refusing to remove unexpected path: $APP" >&2; exit 1 ;;
esac

if [ "$REMOVE_DATA" -eq 1 ]; then
    SUPPORT="$HOME/Library/Application Support/New File Creation 2"
    if [ -d "$SUPPORT" ]; then
        trash_path "$SUPPORT"
    fi
else
    echo "Kept templates and settings in:"
    echo "  $HOME/Library/Application Support/New File Creation 2"
fi

echo "Uninstall complete."
