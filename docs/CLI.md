# `nfc` Command-Line Reference

`nfc` is the headless command-line companion to New File Creation 2. It shares the app’s configuration, templates, naming rules, and lock-based writer with the AppKit app. The app does not need to be running.

## Location and installation

The tool is embedded in the app bundle:

```
/Applications/New File Creation 2.app/Contents/Helpers/nfc
```

Link it onto your `PATH` with the installer:

```bash
./scripts/install-cli.sh                 # ~/.local/bin/nfc
./scripts/install-cli.sh --completion    # also install zsh completion
./scripts/install-cli.sh --man           # also install docs/nfc.1
./scripts/install-cli.sh --alias newfile # optional second name
```

`~/.local/bin` is used by default. Use `--prefix <dir>` to choose another directory. The installer refuses to replace a file or symlink it does not manage. Remove managed links with:

```bash
./scripts/install-cli.sh --uninstall
```

## Synopsis

```
nfc <command> [arguments] [options]
nfc help [command]
nfc version
```

Run `nfc` with no arguments to print the command list. `nfc help create` (or `nfc create --help`) prints command-specific help.

## Global options

Global options may appear anywhere on the command line:

| Option | Effect |
| --- | --- |
| `--json` | Emit one JSON envelope instead of human text. |
| `--quiet`, `-q` | Minimal human output: `create` and `open` print only the path; `add` prints only file names. |
| `--plain` | Accepted for compatibility; output is already plain and uncolored. |
| `--no-color` | Accepted for compatibility; output is never colored. |
| `--config <path>` | Use `<path>` as the config file. Its parent folder becomes the support folder. |
| `--verbose` | Accepted for diagnostics; human output remains stable. |
| `--help`, `-h` | Show help for the command, or general help. |
| `--version`, `-v` | Print the version when used without a command. |

`NFC_SUPPORT_DIR` overrides the support folder for the process and takes precedence over the default location:

```bash
NFC_SUPPORT_DIR="$PWD/test-support" nfc list
```

This is intended for tests and isolated automation. Both `NFC_SUPPORT_DIR` and `--config` point the store at a different `config.json`, `Templates/`, `Backups/`, and `config.lock`.

## Template references

Commands that accept a template use the first matching form:

1. Full template UUID.
2. Exact display name, file name, or file name without extension (case-insensitive).
3. Normalized name, ignoring spaces and punctuation (`Text File`, `text-file`, and `TextFile` all match).
4. Unique case-insensitive prefix.

When a reference is omitted, the configured default template is used. If no default is configured and exactly one template exists, that template is used. If several exist, the command fails with exit code `4` and lists the candidates.

Use `nfc list` to see names and IDs, and `nfc show <template>` for one template’s details.

## Commands

### `create`

```
nfc create [template] [--name <base>] [--output <path>] [--dir <folder>]
           [--no-unique] [--open] [--reveal] [--sound] [--dry-run]
           [--use-app-location] [--template <reference>]
```

Creates a file by copying the selected template into the destination folder.

- The default base name is the app setting `defaultBaseName` (default `Untitled`), not the template’s display name.
- The extension comes from the template file name, e.g. `script.py` produces `Untitled.py`.
- If the base name already ends with the template extension, it is not doubled.
- Existing files are never overwritten. By default the tool appends ` 2`, ` 3`, … to the base name.
- `--output` sets an exact destination path and overrides `--dir` and `--name`.
- `--no-unique` makes an existing destination a conflict (exit code `5`) instead of adding a suffix.
- `--dry-run` prints the destination path that would be used without creating anything.
- `--use-app-location` uses the configured default folder; otherwise the current directory is used.
- `--open`, `--reveal`, and `--sound` apply the matching post-create action.
- `--template <reference>` is an alternative to the positional template argument.

Examples:

```bash
nfc create "Text File"                         # ./Untitled.txt
nfc create script.py --name report             # ./report.py
nfc create "HTML Page" --dir ~/Documents        # ~/Documents/Untitled.html
nfc create "Rich Text" --output ~/Desktop/Invoice.rtf
nfc create "HTML Page" --name "About" --reveal
nfc create "Text File" --dry-run --quiet        # prints the next free path
```

### `list` / `ls`

```
nfc list [--favorites] [--enabled] [--category <name>]
```

Lists templates in configuration order. Disabled templates are included unless `--enabled` is given. `--favorites` and `--category` filter the result. `--all` is accepted and is the default.

Human output is a table with a shortened ID, name, extension, category, favorite state, enabled state, and use count.

### `show` / `info`

```
nfc show [template]
```

Prints the full ID, file name, display name, category, extension, enabled/favorite state, use count, creation date, last-used date, and absolute template path. The JSON form returns the same fields as the `template` object used by `create`, `list`, and `recent`.

### `add`

```
nfc add <file...> [--name <display name>] [--category <name>]
                  [--favorite] [--disabled]
```

Copies one or more files, packages, or folders into `Templates/` and adds template metadata. Existing files in `Templates/` are never overwritten; a unique file name suffix is used when needed.

- `--name` applies when exactly one file is added. For multiple files, names are derived from each source file.
- `--category` applies to every added item. When omitted, the category is inferred from the extension.
- `--favorite` marks the new templates as favorites.
- `--disabled` adds them disabled, so they do not appear in app or Finder menus.

Adding a second file with the same display name is allowed; template references may then become ambiguous.

### `remove` / `rm`

```
nfc remove <template> [--keep-file] [--yes]
```

Removes the template from `config.json`. By default its file is moved to Trash. `--keep-file` leaves the file in `Templates/`, but the library no longer references it. If the removed template was the default, the first remaining template becomes the default.

Without `--yes`, an interactive terminal prompts for confirmation. In a non-interactive session the command refuses to proceed and exits with code `2`.

This command cannot remove the template file from the Trash.

### `favorite` / `fav`

```
nfc favorite [template] [--on|--off]
```

Toggles the favorite flag when neither `--on` nor `--off` is given. Both flags together are a usage error.

### `enable` / `disable`

```
nfc enable <template>
nfc disable <template>
```

Changes whether a template appears in the app grid, quick panel, menu bar menu, and Finder menus. Disabling does not delete the template file.

### `recent`

```
nfc recent [--limit <count>]
```

Lists recently used templates, most recent first. The default limit is 5. Recents are recorded by both the app and the CLI when a file is created.

### `categories` / `cats`

```
nfc categories
```

Lists every category present in the library and its template count, including disabled templates. Categories are stored with stable English identifiers; the app localizes them for display.

### `config`

```
nfc config path
nfc config export [<path>|-]
nfc config import <path>
nfc config reset --yes
```

- `config` with no action is equivalent to `config path`.
- `config path` prints the active `config.json` path.
- `config export` writes pretty-printed, sorted JSON. With no path or `-`, it writes to stdout. With a path, it writes atomically.
- `config import` replaces the entire configuration with the JSON file. Template files are **not** imported; entries whose files are missing will fail when used. The imported object must contain at least a valid schema and template list; missing settings are filled with defaults.
- `config reset --yes` replaces the configuration with defaults. Template files in `Templates/` are kept on disk, but the reset library no longer references them.

`config export --json` returns the configuration object as the envelope’s `data`; `config export <path> --json` returns `{"path": "..."}`. `config import` returns the imported path and template count. `config reset` returns `{"reset": true}`.

### `status`

```
nfc status
```

Prints the app version, config path, template counts, default base name, whether the app is running, Finder extension registration state, login-item status, configured shortcut, CLI path, and whether `nfc` links exist in `~/.local/bin` or `/usr/local/bin`.

JSON fields:

```json
{
  "version": "2.0.0",
  "schemaVersion": 2,
  "revision": 14,
  "configPath": "/Users/example/Library/Application Support/New File Creation 2/config.json",
  "templatesPath": "/Users/example/Library/Application Support/New File Creation 2/Templates",
  "templateCount": 33,
  "enabledCount": 33,
  "favoriteCount": 0,
  "defaultBaseName": "Untitled",
  "defaultTemplateID": "918DBFA6-693A-4544-91B5-2BEDA9D05CDE",
  "appRunning": true,
  "finderExtension": "enabled",
  "loginItemStatus": 3,
  "globalShortcut": "control+option+n",
  "cliPath": "/Applications/New File Creation 2.app/Contents/Helpers/nfc",
  "cliInstalledAtHome": true,
  "cliInstalledGlobally": false
}
```

`loginItemStatus` is the raw `SMAppService` status: `0` not registered, `1` enabled, `2` requires approval, `3` not found, `-1` unavailable. `finderExtension` is `enabled`, `disabled`, `registered`, or `not-registered`.

### `open`

```
nfc open [template]
```

Opens the template file in its default app. With no argument, opens the `Templates/` folder in Finder. `--quiet` suppresses the human confirmation.

### `doctor`

```
nfc doctor
```

Checks the support directory, config readability, schema version, templates directory, missing template files, duplicate file names, duplicate IDs, app installation, Finder extension registration, and CLI links. Each check is reported as `ok`, `warn`, or `fail`; any failure makes the command exit with code `1`.

JSON shape:

```json
{
  "ok": true,
  "command": "doctor",
  "data": {
    "checks": [
      {"name": "support-directory", "status": "ok", "message": "/Users/example/Library/Application Support/New File Creation 2"}
    ],
    "summary": {"pass": 10, "warn": 0, "fail": 0}
  }
}
```

### `completion`

```
nfc completion zsh
nfc completion bash
```

Prints a completion script. With `--json`, the script is returned as a string in `data.script`.

```bash
nfc completion zsh > "${fpath[1]}/_nfc"
nfc completion bash > /usr/local/etc/bash_completion.d/nfc
```

### `help`

```
nfc help [command]
```

Prints general help or command-specific help. `--help` after a command behaves the same way. With `--json`, the text is returned in `data.text`.

### `version`

```
nfc version
```

Prints `nfc 2.0.0`. JSON also includes `schemaVersion`.

### `import-legacy`

```
nfc import-legacy
```

Hidden migration helper used during development. It scans known legacy support locations, copies template files into the current store, and merges settings. Normal installations do not need it.

## Output

### Human output

Data goes to stdout. Warnings and errors go to stderr. Tables are plain text with a header separator. `--quiet` is honored where the command produces a primary path.

### JSON envelope

`--json` writes exactly one object to stdout:

```json
{
  "ok": true,
  "command": "create",
  "data": {
    "path": "/Users/example/Documents/Untitled.txt",
    "name": "Untitled.txt",
    "size": 0,
    "template": {
      "id": "918DBFA6-693A-4544-91B5-2BEDA9D05CDE",
      "fileName": "TextFile.txt",
      "displayName": "Text File",
      "category": "Documents",
      "extension": "txt",
      "enabled": true,
      "favorite": false,
      "useCount": 4,
      "size": 0,
      "path": "/Users/example/Library/Application Support/New File Creation 2/Templates/TextFile.txt",
      "createdAt": "2026-11-15T11:59:45Z",
      "lastUsedAt": "2026-11-15T12:12:11Z"
    }
  }
}
```

On failure:

```json
{
  "ok": false,
  "command": "create",
  "error": {
    "code": "not_found",
    "message": "No template matches “Presentation”.",
    "exitCode": 3,
    "suggestions": ["Keynote Presentation", "ODF Presentation", "PowerPoint Presentation"]
  }
}
```

JSON keys and error codes do not change with system language. Human output is English in v2.0.

## Exit status

| Code | Meaning |
| --- | --- |
| `0` | Success. |
| `1` | General error, or `doctor` found a failure. |
| `2` | Usage error, or a destructive command without confirmation in a non-interactive session. |
| `3` | Template or file not found. |
| `4` | Template reference is ambiguous. |
| `5` | Conflict, such as `--no-unique` with an existing destination. |
| `6` | Configuration error: corrupt file, unsupported schema, or write failure. |
| `7` | Permission error: unwritable destination, unreadable template, or invalid destination. |

## Scripting recipes

### Create a timestamped file

```bash
stamp="$(date +%Y-%m-%d)"
nfc create "Text File" --name "Notes $stamp" --dir ~/Notes --quiet
```

### Find the next free name without creating a file

```bash
nfc create "Rich Text" --name "Untitled" --dry-run --quiet
```

### Add every selected Finder file as a template

```bash
for file in "$@"; do
  nfc add "$file" --category Documents --json
done
```

### Fail the script on a conflict

```bash
if ! nfc create "Text File" --output ./report.txt --no-unique --quiet; then
  status=$?
  if [ "$status" -eq 5 ]; then
    echo "report.txt already exists" >&2
  fi
  exit "$status"
fi
```

### Inspect the default template

```bash
default_id="$(nfc status --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["defaultTemplateID"])')"
nfc show "$default_id" --json
```

## Environment

| Variable | Purpose |
| --- | --- |
| `NFC_SUPPORT_DIR` | Absolute path to an alternate support folder. Intended for tests. |
| `HOME` | Used to locate the default support folder and CLI links. |
| `PATH` | Used by completion and documentation examples; `nfc` itself does not require a specific `PATH`. |

`nfc` makes no network requests.

## Related files

- `~/Library/Application Support/New File Creation 2/config.json` — settings, templates, recents, revision.
- `~/Library/Application Support/New File Creation 2/Templates/` — template files.
- `~/Library/Application Support/New File Creation 2/config.json.bak` — previous configuration.
- `~/Library/Application Support/New File Creation 2/Backups/` — quarantined corrupt configurations.
- `~/Library/Application Support/New File Creation 2/logs/` — local diagnostic log.

## See also

- `docs/nfc.1` — man page source.
- `docs/CLI.md` — this reference.
- `docs/ARCHITECTURE.md` — configuration locking, schema, and shared core.
- `docs/TEST-MATRIX.md` — automated and manual test coverage.
