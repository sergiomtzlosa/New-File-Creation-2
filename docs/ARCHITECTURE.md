# Architecture

New File Creation 2 is a small native macOS system made of four targets that share one Objective-C core:

| Target | Product | Bundle identifier | Sandbox |
| --- | --- | --- | --- |
| `NewFileCreation2` | `New File Creation 2.app` | `com.sid.newfilecreation2` | No |
| `NewFileCreation2Finder` | `New File Creation 2 Finder.appex` | `com.sid.newfilecreation2.finder` | Yes |
| `NewFileCreation2CLI` | `nfc` | `com.sid.newfilecreation2.cli` | No |
| `NewFileCreation2Tests` | `NewFileCreation2Tests.xctest` | `com.sid.newfilecreation2.tests` | Hosted in the app |

The CLI is embedded at `New File Creation 2.app/Contents/Helpers/nfc`. The Finder extension is embedded at `Contents/PlugIns/New File Creation 2 Finder.appex`. Both are ad-hoc signed with the app (`CODE_SIGN_IDENTITY=-`); there is no Team ID, App Group, notarization, or Mac App Store submission.

## Process model

```
┌──────────────────────────────────────────────┐
│ New File Creation 2.app (non-sandboxed)      │
│                                              │
│ NFCAppDelegate                               │
│  ├─ NFCMainWindowController   library        │
│  ├─ NFCQuickPanelController   quick panel    │
│  ├─ NFCMenuBarController      status item    │
│  ├─ NFCSettingsWindowController              │
│  ├─ NFShortcutCenter          Carbon hotkey  │
│  ├─ NFLoginItemManager        SMAppService   │
│  └─ NFCreateCoordinator       shared creation│
│                                              │
│ NFConfigStore (writer)                       │
└──────────────────┬───────────────────────────┘
                   │ flock + atomic rename
                   ▼
┌──────────────────────────────────────────────┐
│ ~/Library/Application Support/               │
│   New File Creation 2/                       │
│   ├─ config.json                             │
│   ├─ config.json.bak                         │
│   ├─ config.lock                             │
│   ├─ Templates/                              │
│   ├─ Backups/                                │
│   └─ logs/                                   │
└──────────────────▲───────────────────────────┘
                   │ read-only config snapshot
                   │ URL-scheme fallback for creation
┌──────────────────┴───────────────────────────┐
│ New File Creation 2 Finder.appex (sandboxed) │
│ NFCFinderSync                                │
│  ├─ NFFinderMenuBuilder (shared)             │
│  ├─ NFFileCreator (shared)  direct attempt   │
│  └─ NFRequest → newfilecreation2://          │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│ nfc (separate process, headless)             │
│ NFCCLIApplication                            │
│  ├─ NFCCLIResolver                           │
│  ├─ NFFileCreator                            │
│  └─ NFConfigStore (writer)                   │
└──────────────────────────────────────────────┘
```

The app and `nfc` are coordinated writers. The Finder extension never writes `config.json`; it reads a snapshot for each menu request. A CLI write posts both a local and a distributed `com.sid.newfilecreation2.configchanged` notification, and the app reloads in response.

## Shared core

`NewFileCreation2Shared/` is compiled directly into the app, Finder extension, CLI, and tests. There is no shared framework to embed or sign separately.

| Folder | Responsibility |
| --- | --- |
| `Models/` | `NFConfig`, `NFTemplate`, defaults, categories, recents, dictionary round-tripping |
| `Store/` | `NFConfigStore`, `NFLock`, revisioned atomic writes, seeding, corruption quarantine |
| `Creation/` | `NFFileCreator`, `NFSanitize`, `NFFilePromiseProvider`, unique naming and safe copies |
| `Config/` | Config path helpers and legacy migration |
| `Requests/` | `NFRequest` URL parsing/building for the app URL scheme |
| `Finder/` | `NFFinderMenuBuilder` menu composition and template icons |
| `Support/` | `NFPaths`, `NFErrors`, `NFLogger`, `NFLocalization`, `NFVersion` |

One behavior is shared by every surface:

- The default base name comes from `settings.defaultBaseName` (default `Untitled`).
- The extension comes from the template file name.
- Existing files are never overwritten; uniqueness appends ` 2`, ` 3`, ...
- A template removal removes metadata and moves the template file to Trash.
- Config writes validate schema and use an interprocess lock.

## Configuration

The file is `config.json` in the support folder. It is versioned by `schemaVersion` (currently `2`) and incremented by `revision` on each successful write.

```json
{
  "schemaVersion": 2,
  "revision": 14,
  "updatedAt": "2026-11-15T11:59:45.744Z",
  "settings": {
    "defaultBaseName": "Untitled",
    "defaultTemplateID": "918DBFA6-693A-4544-91B5-2BEDA9D05CDE",
    "defaultDirectory": "",
    "revealAfterCreate": true,
    "openAfterCreate": false,
    "playSound": false,
    "showToast": true,
    "launchAtLogin": false,
    "showMenuBarIcon": true,
    "showDockIcon": true,
    "globalShortcut": "control+option+n",
    "favoritesFirst": true,
    "groupByCategory": false,
    "showFileIcons": true,
    "includeNewFileInFinderMenu": true,
    "includeAddAsTemplate": true,
    "finderCreationBehavior": "instant",
    "sortMode": "manual",
    "logLevel": "info",
    "onboardingCompleted": true,
    "lastUsedDirectory": "/Users/example/Documents",
    "didSeedBundledTemplates": true
  },
  "templates": [
    {
      "id": "918DBFA6-693A-4544-91B5-2BEDA9D05CDE",
      "fileName": "TextFile.txt",
      "displayName": "Text File",
      "category": "Documents",
      "enabled": true,
      "favorite": false,
      "sortIndex": 0,
      "useCount": 4,
      "source": "included",
      "createdAt": "2026-11-15T11:59:45.738Z",
      "lastUsedAt": "2026-11-15T12:12:11.001Z"
    }
  ],
  "recentTemplateIDs": ["918DBFA6-693A-4544-91B5-2BEDA9D05CDE"],
  "recentFiles": ["/Users/example/Documents/Untitled.txt"]
}
```

Unknown settings are preserved when a config is read and rewritten. Missing settings are filled from defaults. A config with a newer schema is rejected rather than silently downgraded. A corrupt config is moved to `Backups/config-corrupt-<timestamp>.json`; `config.json.bak` is used as a fallback when possible.

## Locking and atomic writes

`NFConfigStore` writes through this sequence:

1. Ensure the support, `Templates/`, and `Backups/` directories exist.
2. Acquire an exclusive `flock` on `config.lock`, with a 5-second timeout.
3. Read the latest `config.json`.
4. Apply the caller's update block.
5. Copy the current config to `config.json.bak`.
6. Write JSON to a hidden temporary file with `O_CREAT|O_EXCL`, `fsync`, and `rename`.
7. `fsync` the support directory.
8. Release the lock and post change notifications.

The write is retried once if the directory or lock is temporarily unavailable. Two simultaneous CLI writers therefore produce a serialized result with no lost update. Every write increments `revision`.

`NFLock` uses `flock(LOCK_EX)` with a polling timeout and releases the descriptor on unlock. The extension only calls the read path and never blocks writers.

## File creation

`NFFileCreator`:

1. Verifies the template exists and is readable.
2. Verifies the destination is an existing, writable directory.
3. Sanitizes the base name: trims whitespace; replaces `/`, `:`, and `\`; removes control characters and leading dots; caps at 200 characters; falls back to `Untitled`.
4. Appends the template extension only if the base name does not already end with it.
5. Computes a unique destination (`Untitled 2.ext`, `Untitled 3.ext`, ...) unless `unique:NO`.
6. Copies with `NSFileManager`; if a race creates the target, retries with the next suffix.
7. Never deletes or replaces an existing destination.

The save panel path uses `NSSavePanel`; because the panel owns explicit replacement confirmation, the app passes the panel's URL directly to the exact-destination creator, which still refuses to overwrite in the non-unique case.

## Finder extension

`NFCFinderSync` is a `FIFinderSync` subclass. It monitors `/` so its menus are available in every Finder folder, and it rebuilds its menu from a fresh config snapshot on each request.

- **New File** submenu: enabled templates only, optional favorites-first, optional category submenus, optional file-type icons. Titles are `New <Template Name>`.
- **Add as Template**: sends selected paths through `newfilecreation2://add-template?path=...` to the non-sandboxed app.
- **Instant creation**: tries `NFFileCreator` directly in the targeted Finder folder.
- **Ask for a name**: shows a small `NSAlert` with a text field, then uses the same creator.
- **Fallback**: if the sandbox denies the copy (`NFErrorDestinationNotWritable` or `NFErrorTemplateUnreadable`), the extension opens `newfilecreation2://create?...` and the app performs the copy and post-create actions.

The extension’s sandbox entitlements include App Sandbox, user-selected read/write, and a read-only temporary exception for the current user’s `Library/Application Support/New File Creation 2/` folder. The config is read from the real home directory via `getpwuid`, because `NSHomeDirectory()` inside a sandbox points at the extension container. See [finder-extension-spike.md](finder-extension-spike.md).

## URL scheme

`newfilecreation2://` is handled by the app for:

| URL | Action |
| --- | --- |
| `newfilecreation2://quick` | Open the quick panel |
| `newfilecreation2://library` | Open the template library |
| `newfilecreation2://settings` | Open Settings |
| `newfilecreation2://add-template?path=<absolute-path>` | Add one or more files as templates |
| `newfilecreation2://create?template=<id-or-name>&dir=<absolute-path>&name=<base>&unique=1&reveal=1&open=1` | Create from a template in a specific folder |

`NFRequest` validates the scheme, host, and absolute paths and rejects traversal before the app touches the filesystem.

## CLI

`nfc` is a headless Foundation/AppKit tool. It uses the same `NFConfigStore`, `NFTemplate`, `NFFileCreator`, `NFSanitize`, `NFPaths`, and `NFLogger` as the app.

- Human output is English in v2.0.
- `--json` writes one JSON envelope to stdout; errors go to the envelope and stderr as appropriate.
- Exit codes: `0` success, `1` general, `2` usage, `3` not found, `4` ambiguous, `5` conflict, `6` config, `7` permission.
- `NFC_SUPPORT_DIR` overrides the support folder for tests.
- Commands never require the app to be running.
- `config export` / `import` operate on JSON; template files live in the support folder and are not embedded in the JSON.

See [CLI.md](CLI.md) for the complete command reference.

## AppKit UI structure

- `NFCMainWindowController` owns an `NSSplitViewController` with a source-list sidebar, a collection-view card grid, and an inspector.
- `NFCQuickPanelController` owns a floating `NSPanel` with a search field, visual template table, and file-promise drag source.
- `NFCMenuBarController` owns the `NSStatusItem`. Left-click toggles the quick panel; right-click or Control-click opens the status menu.
- `NFFilePromiseProvider` writes the template copy when a drop target asks for the promised file, using `defaultBaseName` and the template extension.
- `NFCSettingsWindowController` owns a toolbar-style sidebar window with General, Templates, Finder, Advanced, and About panes.
- `NFCWelcomeWindowController` handles first-run onboarding.
- `NFCreateCoordinator` centralizes creation, post-create actions, add-template panels, save panels, and error alerts.
- `NFShortcutCenter` registers a Carbon global hotkey from the string stored in config.
- `NFLoginItemManager` wraps `SMAppService.mainApp`.
- `NFCLIInstallController` creates or removes `~/.local/bin/nfc` only when it is a symlink managed by the app.

The app uses semantic AppKit colors, Auto Layout, SF Symbols, and system controls throughout; there are no third-party UI dependencies or hardcoded light/dark colors.

## Testing architecture

- The hosted `NewFileCreation2Tests.xctest` bundle imports the app controllers directly. `NFCUIComponentTests` instantiates windows, split views, collection views, the quick panel, settings tabs, and the welcome window without launching the full app UI.
- `NFCDragAndDropTests` models drag destinations with an `NSView` that registers for file URLs and an object that registers for file-promise types. It tests quick-panel `NFFilePromiseProvider` output and grid file-URL pasteboard writers.
- Tests never touch the real support folder: `NFTestCase` assigns `NFPaths` a per-test temporary directory and resets `NFConfigStore` between cases.
- Real destinations are opt-in. `NFC_TEST_REAL_DESKTOP=1` enables the real Desktop test; `NFC_TEST_EXTERNAL_VOLUME=/path/to/volume` enables the external-volume test. `scripts/test.sh` forwards both through `launchctl` for the hosted test process and clears them afterward.
- `NSFilePromiseReceiver` is only valid inside an active drag operation, so promise tests exercise the provider delegate and destination registration rather than a synthesized OS drag session.
- The Finder extension menu builder is tested in-process; enabling the extension and observing Finder toolbars and context menus remain manual.

## Build and signing

`project.yml` is the source of truth. `xcodegen generate` produces the committed Xcode project. The build uses:

```bash
xcodebuild \
  -project NewFileCreation2.xcodeproj \
  -scheme NewFileCreation2 \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=YES build
```

`scripts/build.sh` publishes the Release app to `build/New File Creation 2.app` and verifies the app, extension, and embedded helper with `codesign --verify --deep --strict`.

## Failure handling

- Missing or unreadable template: clear `NSError`; no partial file.
- Unwritable destination: error with the folder name; Finder falls back to the app.
- Corrupt config: quarantine under `Backups/` and try `config.json.bak`.
- Newer schema: refuse to load; do not rewrite.
- Lock timeout: report a config error; no force-write.
- Finder extension disabled/not registered: Settings shows status and offers System Settings, but file creation from the app and CLI continues to work.
