#!/bin/bash
# Install (or remove) a symlink to the nfc helper in New File Creation 2.app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="New File Creation 2.app"
PREFIX="${XDG_BIN_HOME:-$HOME/.local/bin}"
SOURCE_APP=""
ALIAS=""
UNINSTALL=0
INSTALL_COMPLETION=0
INSTALL_MAN=0

usage() {
    cat <<'EOF'
Usage: scripts/install-cli.sh [options]

Options:
  --source <app>   Use a specific New File Creation 2.app
  --prefix <dir>   Install the symlink in <dir> (default: ~/.local/bin)
  --alias <name>   Also install an alias symlink (for example: newfile)
  --completion     Install zsh completion
  --man            Install the nfc(1) man page
  --uninstall      Remove links managed by this script
  -h, --help       Show this help
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --source)
            [ "$#" -ge 2 ] || { echo "--source requires an app path" >&2; exit 2; }
            SOURCE_APP="$2"
            shift 2
            ;;
        --source=*)
            SOURCE_APP="${1#*=}"
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
        --alias)
            [ "$#" -ge 2 ] || { echo "--alias requires a name" >&2; exit 2; }
            ALIAS="$2"
            shift 2
            ;;
        --alias=*)
            ALIAS="${1#*=}"
            shift
            ;;
        --completion)
            INSTALL_COMPLETION=1
            shift
            ;;
        --man)
            INSTALL_MAN=1
            shift
            ;;
        --uninstall)
            UNINSTALL=1
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
LINK="$PREFIX/nfc"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
COMPLETION_FILE="$DATA_HOME/zsh/site-functions/_nfc"
MAN_FILE="$DATA_HOME/man/man1/nfc.1"

managed_link() {
    [ -L "$1" ] || return 1
    local target
    target="$(readlink "$1")"
    case "$target" in
        */"$APP_NAME"/Contents/Helpers/nfc) return 0 ;;
        *) return 1 ;;
    esac
}

if [ "$UNINSTALL" -eq 1 ]; then
    removed=0
    if managed_link "$LINK"; then
        rm -f "$LINK"
        echo "Removed $LINK"
        removed=1
    elif [ -e "$LINK" ] || [ -L "$LINK" ]; then
        echo "Leaving $LINK alone: it is not a symlink managed by this script." >&2
    fi
    if [ -n "$ALIAS" ] && managed_link "$PREFIX/$ALIAS"; then
        rm -f "$PREFIX/$ALIAS"
        echo "Removed $PREFIX/$ALIAS"
        removed=1
    fi
    if [ -f "$COMPLETION_FILE" ]; then
        rm -f "$COMPLETION_FILE"
        echo "Removed $COMPLETION_FILE"
        removed=1
    fi
    if [ -f "$MAN_FILE" ]; then
        rm -f "$MAN_FILE"
        echo "Removed $MAN_FILE"
        removed=1
    fi
    [ "$removed" -eq 1 ] || echo "No managed nfc links found."
    exit 0
fi

find_app() {
    local candidate
    for candidate in \
        "$SOURCE_APP" \
        "/Applications/$APP_NAME" \
        "$HOME/Applications/$APP_NAME" \
        "$ROOT/build/$APP_NAME" \
        "$ROOT/build/DerivedData/Build/Products/Release/$APP_NAME" \
        "$ROOT/build/DerivedData/Build/Products/Debug/$APP_NAME"
    do
        if [ -n "$candidate" ] && [ -x "$candidate/Contents/Helpers/nfc" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

APP="$(find_app || true)"
if [ -z "$APP" ]; then
    echo "New File Creation 2.app was not found; building it now..."
    "$ROOT/scripts/build.sh" >/dev/null
    APP="$(find_app || true)"
fi
if [ -z "$APP" ]; then
    echo "Could not find New File Creation 2.app. Run scripts/install.sh first." >&2
    exit 1
fi

CLI="$APP/Contents/Helpers/nfc"
[ -x "$CLI" ] || { echo "Missing embedded helper: $CLI" >&2; exit 1; }
mkdir -p "$PREFIX"

if [ -e "$LINK" ] || [ -L "$LINK" ]; then
    if ! managed_link "$LINK"; then
        echo "Refusing to replace $LINK: it is not managed by this script." >&2
        exit 1
    fi
fi
ln -sfn "$CLI" "$LINK"
echo "Installed $LINK -> $CLI"

if [ -n "$ALIAS" ]; then
    ln -sfn "$CLI" "$PREFIX/$ALIAS"
    echo "Installed alias $PREFIX/$ALIAS"
fi

if [ "$INSTALL_COMPLETION" -eq 1 ]; then
    mkdir -p "$(dirname "$COMPLETION_FILE")"
    "$CLI" completion zsh > "$COMPLETION_FILE"
    echo "Installed zsh completion: $COMPLETION_FILE"
fi

if [ "$INSTALL_MAN" -eq 1 ]; then
    if [ -f "$ROOT/docs/nfc.1" ]; then
        mkdir -p "$(dirname "$MAN_FILE")"
        cp "$ROOT/docs/nfc.1" "$MAN_FILE"
        echo "Installed man page: $MAN_FILE"
    else
        echo "docs/nfc.1 is missing; skipping the man page." >&2
    fi
fi

case ":$PATH:" in
    *":$PREFIX:"*) ;;
    *)
        echo
        echo "$PREFIX is not on PATH. Add this to your shell profile:"
        echo "  export PATH=\"$PREFIX:\$PATH\""
        ;;
esac
