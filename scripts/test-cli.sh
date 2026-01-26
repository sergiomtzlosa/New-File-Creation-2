#!/bin/bash
# Exercise the nfc CLI end to end with an isolated support directory.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

pass() {
    echo "ok: $*"
}

json_ok() {
    python3 - "$1" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    document = json.load(handle)
if document.get("ok") is not True:
    raise SystemExit("not ok: %r" % (document,))
PY
}

json_query() {
    python3 - "$1" "$2" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    value = json.load(handle)
for part in sys.argv[2].split("."):
    if part.isdigit():
        value = value[int(part)]
    else:
        value = value[part]
print(value)
PY
}

find_cli() {
    if [ -n "${NFC_BIN:-}" ]; then
        [ -x "$NFC_BIN" ] || fail "NFC_BIN is not executable: $NFC_BIN"
        CLI="$NFC_BIN"
        return
    fi
    for candidate in \
        "$ROOT/build/New File Creation 2.app/Contents/Helpers/nfc" \
        "$ROOT/build/DerivedData/Build/Products/Release/New File Creation 2.app/Contents/Helpers/nfc" \
        "$ROOT/build/DerivedData/Build/Products/Debug/New File Creation 2.app/Contents/Helpers/nfc"
    do
        if [ -x "$candidate" ]; then
            CLI="$candidate"
            return
        fi
    done
    echo "No nfc binary found; building the app first..."
    "$ROOT/scripts/build.sh" >/dev/null
    CLI="$ROOT/build/New File Creation 2.app/Contents/Helpers/nfc"
    [ -x "$CLI" ] || fail "the embedded nfc helper is missing"
}

TMP="$(mktemp -d "${TMPDIR:-/tmp}/nfc-cli-tests.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
SUPPORT="$TMP/support"
WORK="$TMP/work"
mkdir -p "$SUPPORT" "$WORK"
export NFC_SUPPORT_DIR="$SUPPORT"

find_cli
echo "Using $CLI"
echo "Support $SUPPORT"

"$CLI" version --json > "$TMP/version.json"
json_ok "$TMP/version.json"
[ "$(json_query "$TMP/version.json" data.version)" = "2.0.0" ] || fail "unexpected version"
pass "version"

"$CLI" list --json > "$TMP/list.json"
json_ok "$TMP/list.json"
count="$(json_query "$TMP/list.json" data.count)"
[ "$count" -ge 30 ] || fail "expected the bundled templates to be seeded, got $count"
pass "bundled templates seeded ($count)"

"$CLI" status --json > "$TMP/status.json"
json_ok "$TMP/status.json"
[ "$(json_query "$TMP/status.json" data.templateCount)" -ge 30 ] || fail "status count is wrong"
pass "status"

DEFAULT_PATH="$("$CLI" create script.py --dir "$WORK" --quiet)"
[ -f "$DEFAULT_PATH" ] || fail "default create did not produce a file"
[ "$(basename "$DEFAULT_PATH")" = "Untitled.py" ] || fail "default name was not used: $DEFAULT_PATH"
cmp -s "$DEFAULT_PATH" "$SUPPORT/Templates/script.py" || fail "created file content does not match the template"
pass "default name from settings"

SECOND_PATH="$("$CLI" create "Python Script" --dir "$WORK" --quiet 2>/dev/null || true)"
if [ -z "$SECOND_PATH" ]; then
    SECOND_PATH="$("$CLI" create script.py --dir "$WORK" --quiet)"
fi
[ -f "$SECOND_PATH" ] || fail "second create did not produce a file"
[ "$(basename "$SECOND_PATH")" = "Untitled 2.py" ] || fail "unique suffix missing: $SECOND_PATH"
pass "unique suffix"

NAMED_PATH="$("$CLI" create script.py --dir "$WORK" --name Report --quiet)"
[ "$(basename "$NAMED_PATH")" = "Report.py" ] || fail "--name was not honored: $NAMED_PATH"
pass "--name"

OUTPUT_PATH="$WORK/Explicit.py"
"$CLI" create script.py --output "$OUTPUT_PATH" --quiet >/dev/null
[ -f "$OUTPUT_PATH" ] || fail "--output was not honored"
pass "--output"

set +e
"$CLI" create script.py --output "$OUTPUT_PATH" --no-unique --quiet >/dev/null 2>&1
conflict=$?
set -e
[ "$conflict" -eq 5 ] || fail "expected exit 5 for --no-unique, got $conflict"
pass "conflict exit code"

DRY_PATH="$("$CLI" create script.py --dir "$WORK" --name DryRun --dry-run --quiet)"
[ ! -e "$DRY_PATH" ] || fail "--dry-run created a file"
pass "--dry-run"

printf 'custom template contents\n' > "$WORK/custom.nfc"
"$CLI" add "$WORK/custom.nfc" --name "Custom Template" --category "Other" --favorite --json > "$TMP/add.json"
json_ok "$TMP/add.json"
[ "$(json_query "$TMP/add.json" data.count)" = "1" ] || fail "add did not report one template"
pass "add"

"$CLI" show "Custom Template" --json > "$TMP/show.json"
json_ok "$TMP/show.json"
[ "$(json_query "$TMP/show.json" data.displayName)" = "Custom Template" ] || fail "show returned the wrong template"
pass "show"

"$CLI" disable "Custom Template" --json > "$TMP/disable.json"
json_ok "$TMP/disable.json"
"$CLI" list --enabled --json > "$TMP/enabled.json"
python3 - "$TMP/enabled.json" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    document = json.load(handle)
if any(item["displayName"] == "Custom Template" for item in document["data"]["templates"]):
    raise SystemExit("disabled template still appears in --enabled")
PY

"$CLI" enable "Custom Template" --json > "$TMP/enable.json"
json_ok "$TMP/enable.json"
pass "enable and disable"

"$CLI" favorite "Custom Template" --off --json > "$TMP/favorite.json"
json_ok "$TMP/favorite.json"
[ "$(json_query "$TMP/favorite.json" data.favorite)" = "False" ] || fail "favorite --off did not clear the flag"
pass "favorite"

"$CLI" recent --json > "$TMP/recent.json"
json_ok "$TMP/recent.json"
pass "recent"

"$CLI" categories --json > "$TMP/categories.json"
json_ok "$TMP/categories.json"
pass "categories"

"$CLI" config export "$TMP/config.json" >/dev/null
[ -s "$TMP/config.json" ] || fail "config export is empty"
"$CLI" config import "$TMP/config.json" --json > "$TMP/import.json"
json_ok "$TMP/import.json"
pass "config export and import"

"$CLI" completion bash > "$TMP/completion.bash"
grep -q "_nfc_completions" "$TMP/completion.bash" || fail "bash completion is missing"
pass "completion"

"$CLI" doctor --json > "$TMP/doctor.json"
json_ok "$TMP/doctor.json"
pass "doctor"

# Two concurrent writers must not lose an update thanks to the config lock.
printf 'concurrent one\n' > "$WORK/concurrent-one.txt"
printf 'concurrent two\n' > "$WORK/concurrent-two.txt"
"$CLI" add "$WORK/concurrent-one.txt" --json > "$TMP/concurrent-1.json" 2>&1 &
pid1=$!
"$CLI" add "$WORK/concurrent-two.txt" --json > "$TMP/concurrent-2.json" 2>&1 &
pid2=$!
wait "$pid1" || fail "first concurrent add failed"
wait "$pid2" || fail "second concurrent add failed"
json_ok "$TMP/concurrent-1.json"
json_ok "$TMP/concurrent-2.json"
"$CLI" list --json > "$TMP/list-after-concurrent.json"
json_ok "$TMP/list-after-concurrent.json"
python3 - "$TMP/list-after-concurrent.json" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    document = json.load(handle)
names = {item["fileName"] for item in document["data"]["templates"]}
if "concurrent-one.txt" not in names or "concurrent-two.txt" not in names:
    raise SystemExit("a concurrent add was lost")
PY
pass "concurrent writers"

"$CLI" remove "Custom Template" --yes --json > "$TMP/remove.json"
json_ok "$TMP/remove.json"
"$CLI" list --json > "$TMP/list-after-remove.json"
python3 - "$TMP/list-after-remove.json" <<'PY'
import json
import sys
with open(sys.argv[1], encoding="utf-8") as handle:
    document = json.load(handle)
if any(item["displayName"] == "Custom Template" for item in document["data"]["templates"]):
    raise SystemExit("removed template still appears")
PY
pass "remove"

echo
echo "All CLI checks passed."
