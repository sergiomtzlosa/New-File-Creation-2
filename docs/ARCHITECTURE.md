# Architecture

New File Creation 2 is a small native macOS system made of six targets built around one shared Objective-C core:

| Target | Product | Bundle identifier | Sandbox |
| --- | --- | --- | --- |
| `NewFileCreation2` | `New File Creation 2.app` | `com.sid.newfilecreation2` | No |
| `NewFileCreation2Finder` | `New File Creation 2 Finder.appex` | `com.sid.newfilecreation2.finder` | Yes |
| `NewFileCreation2Today` | `New File Creation 2 Today.appex` | `com.sid.newfilecreation2.today` | Yes |
| `NewFileCreation2Widget` | `New File Creation 2 Widget.appex` | `com.sid.newfilecreation2.widget` | Yes |
| `NewFileCreation2CLI` | `nfc` | `com.sid.newfilecreation2.cli` | No |
| `NewFileCreation2Tests` | `NewFileCreation2Tests.xctest` | `com.sid.newfilecreation2.tests` | Hosted in the app |
| `NewFileCreation2UITests` | `NewFileCreation2UITests.xctest` | `com.sid.newfilecreation2.uitests` | UI runner |

The CLI is embedded at `New File Creation 2.app/Contents/Helpers/nfc`. The Finder, Today, and WidgetKit extensions are embedded at `Contents/PlugIns/New File Creation 2 Finder.appex`, `Contents/PlugIns/New File Creation 2 Today.appex`, and `Contents/PlugIns/New File Creation 2 Widget.appex`. Local development builds are ad-hoc signed with the app (`CODE_SIGN_IDENTITY=-`), with no Team ID or App Group. `scripts/release.sh` can rebuild with a Developer ID Application identity, notarize the archive, and generate a Homebrew cask; the project does not target the Mac App Store.

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
│ New File Creation 2 Today.appex (sandboxed)  │
│ NFFTodayViewController                       │
│  ├─ NFTodayTemplateSource  read-only config  │
│  └─ NFFilePromiseProvider  drag source       │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│ New File Creation 2 Widget.appex (sandboxed) │
│ SwiftUI + WidgetKit                          │
│  ├─ config.json reader (real home via pw)    │
│  ├─ template grid, small/medium/large        │
│  └─ Link → newfilecreation2://create?…       │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│ nfc (separate process, headless)             │
│ NFCCLIApplication                            │
│  ├─ NFCCLIResolver                           │
│  ├─ NFFileCreator                            │
│  └─ NFConfigStore (writer)                   │
└──────────────────────────────────────────────┘
```

The app and `nfc` are coordinated writers. The Finder, Today, and WidgetKit extensions never write `config.json`; they read a snapshot for each menu request or widget reload. A CLI or Settings write posts both a local and a distributed `com.sid.newfilecreation2.configchanged` notification, and the app reloads in response. When the app observes a change, it also asks WidgetKit to reload timelines through a small Swift bridge.

The app target is an `LSUIElement` menu bar accessory. It never owns a Dock icon or a Dock-owned main window. The library, quick panel, Settings, and Get Started are all `NFCFloatingPanel` instances: floating-level `NSPanel`s opened from the status item, with `hidesOnDeactivate = NO`, `releasedWhenClosed = NO`, and no minimize button. Closing a panel leaves the status item and app running; Quit is available from the status menu.

## Shared core

`NewFileCreation2Shared/` is compiled directly into the app, Finder and Today extensions, CLI, and tests. There is no shared framework to embed or sign separately. The WidgetKit extension is deliberately standalone SwiftUI: it decodes the few template fields it needs from `config.json` and links back into the app for creation, so it does not need the Objective-C core or a bridging header.

| Folder | Responsibility |
| --- | --- |
| `Models/` | `NFConfig`, `NFTemplate`, defaults, categories, recents, dictionary round-tripping |
| `Store/` | `NFConfigStore`, `NFLock`, revisioned atomic writes, seeding, corruption quarantine |
| `Creation/` | `NFFileCreator`, `NFSanitize`, `NFFilePromiseProvider`, unique naming and safe copies |
| `Config/` | Config path helpers and legacy migration |
| `Requests/` | `NFRequest` URL parsing/building for the app URL scheme |
| `Finder/` | `NFFinderMenuBuilder` menu composition, template icons, and persisted sort modes |
| `Today/` | `NFTodayTemplateSource` read-only config and template loading for the widget |
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
    "soundName": "Glass",
    "showToast": true,
    "launchAtLogin": false,
    "showMenuBarIcon": true,
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
    "customCategories": ["Client Work"],
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

`defaultDirectory` is authoritative for **Create File**, **Create in Default Folder**, and the save panel's starting location. If it is empty or no longer resolves to a directory, creation falls back to `lastUsedDirectory` and then the Desktop. Saving a file elsewhere updates `lastUsedDirectory` for that fallback but never overrides a configured default folder.

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

`NFCFinderSync` is a `FIFinderSync` subclass. It registers `/` for the boot volume and every mounted volume in `FIFinderSyncController.directoryURLs`, and refreshes that set when volumes mount, unmount, or are renamed. Finder Sync treats volumes as separate monitoring roots, so registering only `/` leaves external and removable disks without a menu. The menu is rebuilt from a fresh config snapshot on each request.

- **New File** submenu: enabled templates only, optional favorites-first, optional category submenus, optional file-type icons. Titles are `New <Template Name>`. Each item carries a positive integer tag, and the extension keeps a tag-to-template-identifier snapshot because `representedObject` does not survive the Finder Sync XPC boundary.
- **Add as Template**: sends selected paths through `newfilecreation2://add-template?path=...` to the non-sandboxed app.
- **Creation handoff**: Finder extensions are sandboxed and cannot write to arbitrary folders or the Desktop. Selecting a template builds an `NFRequest` and opens `newfilecreation2://create?...` through `NSWorkspace`; if that fails, the extension tries its `NSExtensionContext` `openURL:completionHandler:` and then shows an error. The app performs the copy, post-create actions, and recents update.
- **Ask for a name**: shows a small `NSAlert` with a text field in the extension, then hands the request to the app with the entered base name.

The extension’s sandbox entitlements include App Sandbox, user-selected read/write, and a read-only temporary exception for the current user’s `Library/Application Support/New File Creation 2/` folder. The config is read from the real home directory via `getpwuid`, because `NSHomeDirectory()` inside a sandbox points at the extension container. See [finder-extension-spike.md](finder-extension-spike.md).

## WidgetKit extension

`NewFileCreation2Widget` is a SwiftUI/WidgetKit target with one `StaticConfiguration` widget in small, medium, and large families. It reads `config.json` from the real home directory (again via `getpwuid`), filters disabled templates, and applies the persisted `favoritesFirst` and `sortMode` settings. Each template is a `Link` to `newfilecreation2://create?template=<id>&unique=1`; the app resolves the default folder and performs the copy, so the sandboxed widget never writes user files. The header opens the quick panel, and the empty state opens Settings.

The widget uses `containerBackground(for: .widget)` on macOS 14 and later and a plain gradient background on macOS 13. A five-minute timeline policy picks up edits made while the app is not running. When the app is running, `NFCAppDelegate` calls `WidgetCenter.shared.reloadAllTimelines()` for both its own config writes and CLI writes observed through the distributed change notification. The legacy Today extension remains embedded for older releases, but macOS versions that removed `com.apple.widget-extension` use this WidgetKit extension instead.

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

- `NFCFloatingPanel` is the shared floating `NSPanel` base for every app window. It uses `NSFloatingWindowLevel`, does not hide on deactivation, is not released on close, can join all Spaces, and cannot become the main window.
- `NFCMainWindowController` owns an `NSSplitViewController` with a source-list sidebar, a collection-view card grid, and an inspector inside a floating library panel.
- `NFCQuickPanelController` owns a floating quick panel with a search field, visual template table, app-icon Get Started button, gear button, power button, and file-promise drag source. It reloads the shared config when shown.
- `NFCMenuBarController` owns the permanent `NSStatusItem`. Left-click toggles the quick panel; right-click or Control-click opens the status menu with library, Get Started, settings, about, and quit. The template submenu is rebuilt on each open.
- `NFCTodayViewController` owns the Today widget table and its file-promise drag source.
- `NewFileCreation2Widget` owns the WidgetKit template grid and its `newfilecreation2://create` links.
- `NFFilePromiseProvider` writes the template copy when a drop target asks for the promised file, using `defaultBaseName` and the template extension.
- `NFCSettingsWindowController` owns a floating utility panel with icon tabs for General, Templates, Finder, Advanced, Help, and About, and resizes to each pane’s preferred size. Sound name, sort mode, custom-category editing, and category removal live here.
- `NFCWelcomeWindowController` owns the floating Get Started window and its inline inspector aside; it is opened from the menu bar menu, the quick-panel app icon, Settings › Help, or the app menu rather than automatically at launch.
- `NFCreateCoordinator` centralizes creation, post-create actions, the configurable sound, add-template panels, save panels, and error alerts.
- `NFShortcutCenter` registers a Carbon global hotkey from the string stored in config.
- `NFLoginItemManager` wraps `SMAppService.mainApp`.
- `NFCLIInstallController` creates or removes `~/.local/bin/nfc` only when it is a symlink managed by the app.

The app uses semantic AppKit colors, Auto Layout, SF Symbols, and system controls throughout; there are no third-party UI dependencies or hardcoded light/dark colors.

## Testing architecture

- The hosted `NewFileCreation2Tests.xctest` bundle imports the app controllers directly. `NFCUIComponentTests` instantiates floating panels, split views, collection views, the quick panel, six settings tabs, and the Get Started window without launching the full app UI. It also checks that the app is an `LSUIElement` accessory and that all panels use floating-level styling.
- `NFTodayTemplateSourceTests` exercises the Today widget’s read-only config loading, enabled/favorites filtering, and persisted sort modes without launching Notification Center.
- `NFCUIComponentTests` covers the quick-panel quit button alongside the existing close, gear, Get Started, search, and drag-hint assertions.
- `NFLocalizationTests` checks all 28 v1 languages for key parity, non-empty values, preserved placeholders, preserved product name, Finder strings, and the quick-panel drag hint.
- `NewFileCreation2UITests` launches the real app with an isolated support folder and drives the quick panel, Settings, the Help tab, and the Get Started aside through XCUITest.
- `NFCDragAndDropTests` models drag destinations with an `NSView` that registers for file URLs and an object that registers for file-promise types. It tests quick-panel `NFFilePromiseProvider` output and grid file-URL pasteboard writers.
- Tests never touch the real support folder: `NFTestCase` assigns `NFPaths` a per-test temporary directory and resets `NFConfigStore` between cases.
- Real destinations are opt-in. `NFC_TEST_REAL_DESKTOP=1` enables the real Desktop test; `NFC_TEST_EXTERNAL_VOLUME=/path/to/volume` enables the external-volume test. `scripts/test.sh` forwards both through `launchctl` for the hosted test process and clears them afterward.
- `NSFilePromiseReceiver` is only valid inside an active drag operation, so promise tests exercise the provider delegate and destination registration rather than a synthesized OS drag session.
- The Finder extension menu builder and destination logic are tested in-process; Finder toolbar interaction and creating a file from the Finder menu remain manual. Desktop, Finder-window, and external-volume menus were verified manually on 2026-11-16. Today widget drag gestures and WidgetKit gallery placement remain manual checks.

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

`scripts/build.sh` publishes the Release app to `build/New File Creation 2.app` and verifies the app, Finder extension, Today extension, WidgetKit extension, and embedded helper with `codesign --verify --deep --strict`. It accepts `CODE_SIGN_IDENTITY` and `DEVELOPMENT_TEAM` overrides so local builds stay ad-hoc while release builds use a Developer ID.

`scripts/release.sh` wraps the build and verification, checks the hardened runtime on every executable, creates the zip and SHA-256 file, and renders the Homebrew cask from `packaging/homebrew/new-file-creation-2.rb.template`. With a Developer ID identity it can submit to `notarytool`, staple the ticket, upload the archive with `gh`, and copy the cask into a tap checkout.

## Failure handling

- Missing or unreadable template: clear `NSError`; no partial file.
- Unwritable destination: error with the folder name; Finder falls back to the app.
- Corrupt config: quarantine under `Backups/` and try `config.json.bak`.
- Newer schema: refuse to load; do not rewrite.
- Lock timeout: report a config error; no force-write.
- Finder extension disabled/not registered: Settings shows status and offers System Settings, but file creation from the app and CLI continues to work.
