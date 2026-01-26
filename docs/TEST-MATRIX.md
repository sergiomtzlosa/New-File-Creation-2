# Test Matrix

This document records how New File Creation 2 is verified. Automated suites cover the shared model, configuration store, naming, creation, URL handling, Finder menu composition, localization, the CLI, programmatic AppKit UI components, and drag-and-drop file promises into custom windows and folders. Manual checks cover OS-level drag gestures, Finder integration, real menu-bar interaction, and distribution behavior.

## Environment

| Item | Value |
| --- | --- |
| macOS | 26 (Darwin 25.x), Apple silicon |
| Xcode | 27.2 |
| XcodeGen | 2.46 |
| Build | Ad-hoc signed, `CODE_SIGN_IDENTITY=-` |
| App | `build/New File Creation 2.app` (Release) |
| Test host | Debug app, XCTest bundle `NewFileCreation2Tests.xctest` |

## Automated suites

Run all automated checks with:

```bash
./scripts/test.sh       # XCTest, 79 tests
./scripts/test-cli.sh   # isolated end-to-end CLI checks
./scripts/verify.sh     # signing, bundle, resources, then both suites
```

Last automated run: **2026-11-15**. XCTest: **78 passed, 1 skipped, 0 failed (~7 s)**. The skipped test is the external-volume drag test because no writable external volume was mounted. Opt-in runs also passed with `NFC_TEST_REAL_DESKTOP=1` against the real Desktop and with `NFC_TEST_EXTERNAL_VOLUME` pointing at a temporary writable disk image. CLI integration: **20 passed, 0 failed**. Release verification: **21 passed, 1 warning, 0 failed**; the warning is that the Finder extension is registered but not enabled. `scripts/verify.sh --no-build --quick` reports the 19 static bundle/signature checks.

### XCTest

| Suite | Tests | What is covered |
| --- | ---: | --- |
| `NFModelTests` | 7 | Defaults, config round-trip, unknown settings, template round-trip, category inference, display-name heuristics, bounded/deduplicated recents. |
| `NFConfigStoreTests` | 7 | First-load seeding, read-only snapshot without writes, revisioned updates, cancelled updates, serialized concurrent writers, corrupt-config quarantine and backup, config replacement, custom-store isolation. |
| `NFFileCreatorTests` | 7 | Default name and extension, no double extension, unique suffix behavior, non-unique conflicts, missing template/destination errors, exact destination uniqueness, content copy. |
| `NFFilePromiseProviderTests` | 5 | Default and sanitized promise names, UTI selection and fallback, directory promises, non-overwriting copy, write callbacks. |
| `NFSanitizeTests` | 7 | Path separators and control characters, leading punctuation, fallback name, length cap, valid names, unique destination helpers, extensions. |
| `NFRequestTests` | 7 | Quick/library requests, create request round-trip, add-template request round-trip, scheme and host rejection, relative/traversal path rejection, missing template. |
| `NFFinderMenuBuilderTests` | 4 | Enabled-only menus, favorites first, category submenus, empty placeholder. |
| `NFCLITests` | 8 | Option parsing (values, flags, combined short flags, `--`), unknown/missing values, resolver by ID/name/normalized name, unique prefix, default selection, ambiguity, missing references. |
| `NFCUITests` | 3 | Main-menu search/reveal/full-screen shortcuts, core File menu commands, bundled README for Help. |
| `NFLocalizationTests` | 5 | English/Spanish key parity, no empty values, Finder-specific translations, quick-panel drag hint, missing-key fallback. |
| `NFCUIComponentTests` | 12 | Main menu; three-pane library window and toolbar; sidebar filters; grid search/sort/selection/empty state; context menu commands; collection card rendering and double-click; inspector metadata and commands; quick-panel rows, search, and drag hint; status-item menu and visibility; all five Settings panes; Welcome window actions; toast message and action. |
| `NFCDragAndDropTests` | 7 | Quick-panel file promises into a Finder-style folder, a custom promise-aware window, and a desktop-style folder; grid file-URL drops into a custom drop window; opt-in real Desktop drop; opt-in external-volume drop; missing-template drag rejection; no-overwrite behavior and metadata updates. |

Full log: `build/test.log` after `scripts/test.sh`.

### AppKit UI and drag/drop automation

The app’s UI is built programmatically, so the hosted XCTest target instantiates controllers and windows directly and inspects the resulting AppKit view tree. Tests use accessibility identifiers such as `TemplateSidebar`, `TemplateGrid`, `QuickPanelTemplateTable`, and `SettingsTabs`, plus KVC for private controller state.

Drag destinations are modeled without OS-level mouse automation:

- **Custom window:** `NFCTestFileDropView` registers for file URLs and copies them into its destination folder.
- **Promise-aware window:** `NFCTestPromiseDropWindow` registers for `NSFilePromiseReceiver.readableDraggedTypes` and resolves the provider through its delegate.
- **Desktop-style folder:** a temporary folder named `Desktop` exercises the same copy path as a real desktop destination.
- **Real Desktop:** opt in with `NFC_TEST_REAL_DESKTOP=1`; the test creates and removes a hidden temporary folder on the actual Desktop.
- **External volume:** mount any writable non-internal volume, or set `NFC_TEST_EXTERNAL_VOLUME` to a writable directory. The test is skipped when neither is available.

`NSFilePromiseReceiver` cannot be invoked outside a real drag session; AppKit raises `receivePromisedFilesAtDestination:... can only be called during -prepareForDragOperation:, -performDragOperation:, and -concludeDragOperation:`. The promise tests therefore validate the provider’s fileName/write delegate contract and the destination’s registration, while the manual Q9/Q10 checks remain the end-to-end gesture test.


### CLI integration

`scripts/test-cli.sh` builds or reuses the embedded `nfc`, creates an isolated `NFC_SUPPORT_DIR`, and verifies:

1. `version --json` reports `2.0.0`.
2. First `list` seeds the 33 bundled templates.
3. `status --json` reports the template count.
4. `create` uses `defaultBaseName` (`Untitled.py`).
5. A second create appends ` 2` (`Untitled 2.py`).
6. `--name` overrides the base name.
7. `--output` creates the exact path.
8. `--no-unique` returns exit code `5` for an existing destination.
9. `--dry-run` does not create a file.
10. `add` copies a file and reports one template.
11. `show` returns the added template by name.
12. `disable` hides a template from `list --enabled`; `enable` restores it.
13. `favorite --off` clears the flag.
14. `recent` succeeds.
15. `categories` succeeds.
16. `config export` / `config import` round-trips JSON.
17. `completion bash` emits `_nfc_completions`.
18. `doctor --json` returns a well-formed envelope.
19. Two concurrent `add` processes both persist (no lost update).
20. `remove --yes` removes metadata and reports success.

The script exits non-zero on the first failed assertion.

### Release verification

`scripts/verify.sh --no-build --quick` checks:

| Check | Method |
| --- | --- |
| App signature | `codesign --verify --deep --strict` |
| Finder extension signature | `codesign --verify --strict` |
| `nfc` signature | `codesign --verify --strict` |
| `nfc` executable | executable bit and path |
| Finder extension embedded | `.appex` exists under `Contents/PlugIns` |
| App / Finder plists | `plutil -lint` |
| Version | `CFBundleShortVersionString == 2.0.0` |
| Bundle identifiers | app, extension |
| Finder principal class | `NFCFinderSync` |
| URL scheme | `newfilecreation2` |
| Localization resources | `en.lproj` and `es.lproj` in app and extension |
| Localization parity | matching keys and non-empty values |
| Bundled templates | at least 30 files under `Resources/Templates` |
| App icon | `AppIcon.icns` present |
| Finder registration | `pluginkit -m -i com.sid.newfilecreation2.finder` |

## Manual test matrix

These checks are not fully automated in the repository. Run them after UI or Finder changes, or before a release. Rows marked **Automated** have in-process XCTest coverage but still merit an OS-level smoke test when permissions allow.

### App launch and first run

| ID | Check | Expected | Status |
| --- | --- | --- | --- |
| A1 | Launch with an empty support folder | Welcome window appears; 33 templates are seeded; config is created. | Pending |
| A2 | Relaunch | Settings and template state persist; welcome does not reappear. | Pending |
| A3 | Launch with corrupt `config.json` | Warning is shown; corrupt file is quarantined under `Backups/`; app remains usable. | Pending |
| A4 | Launch with newer `schemaVersion` | App refuses to downgrade and reports a clear error. | Pending |
| A5 | Quit and reopen while `nfc` changed config | App reloads templates and settings. | Pending |

### Library window

| ID | Check | Expected | Status |
| --- | --- | --- | --- |
| L1 | Sidebar counts | All, Favorites, Recent, and category counts match `nfc list`. | Pending |
| L2 | Search | Typing filters by display name, file name, category, and extension. | Pending |
| L3 | ⌘F | Focuses the toolbar search field, inserting it if it was removed. | Pending |
| L4 | Return | Creates from the selected template in the default folder. | Pending |
| L5 | Double-click a card | Creates immediately. | Pending |
| L6 | Drag a card to Finder | Copies the template file; Finder resolves collisions. | Automated (file URL) |
| L7 | Context menu | New File, New File…, Favorite, Reveal, Rename, Remove all work. | Pending |
| L8 | ⌘R | Reveals the selected template in Finder; disabled with no selection. | Pending |
| L9 | Inspector | Favorite, Enabled, Reveal, Remove, New File, and New File… reflect the selection. | Pending |
| L10 | Add Template | Multi-select files/packages/folders; all are copied and appear in the grid. | Pending |
| L11 | Empty library | Empty state appears with Add Template…; Finder shows “No Templates”. | Pending |

### Quick panel and menu bar

| ID | Check | Expected | Status |
| --- | --- | --- | --- |
| Q1 | Global shortcut | Control-Option-N opens the quick panel from another app. | Pending |
| Q2 | Search and arrows | Typing filters; ↑/↓ move selection; Return creates; Esc closes. | Pending |
| Q3 | No matches | “No matching templates” is shown; Return does nothing harmful. | Pending |
| Q4 | Left-click status icon | Toggles the visual quick panel anchored below the icon; rows show 32×32 icons, metadata, and the drag hint. | Pending |
| Q5 | Right-click status icon | Menu shows quick panel, New File templates, Add Template, Library, Settings, About, Quit. | Pending |
| Q6 | Disable menu bar icon | Status item disappears; shortcut still opens the quick panel. | Pending |
| Q7 | Disable Dock and menu bar icons | Second checkbox is refused with an explanatory alert; one remains visible. | Pending |
| Q8 | Both icons disabled in hand-edited config | App remains reachable through the global shortcut or activation policy. | Pending |
| Q9 | Drag a template row to Finder | A file-promise drop creates `defaultBaseName.ext` in the target folder; Finder resolves collisions; recent/last-folder metadata updates; the panel closes. | Automated (promise) |
| Q10 | Drag to another window | A file-promise-aware target such as TextEdit accepts the drop and writes a default-named copy; cancelling the drag leaves the panel usable. | Automated (mock window) |

### Settings

| ID | Check | Expected | Status |
| --- | --- | --- | --- |
| S1 | Change default name | App, Finder, and CLI all use the new `defaultBaseName`. | Pending |
| S2 | Change default folder/template | New File uses the new values. | Pending |
| S3 | Post-create options | Reveal, open, sound, and toast behave as checked. | Pending |
| S4 | Launch at login | `SMAppService` registers; approval state is explained. | Pending |
| S5 | Global shortcut presets | Each preset registers; conflicts revert to the previous shortcut. | Pending |
| S6 | Templates pane | Add, remove, enable/disable, set default; removed files go to Trash. | Pending |
| S7 | Finder pane | Status text is accurate; Enable Extension works or opens System Settings. | Pending |
| S8 | Advanced export/import/reset | Round-trip works; reset keeps template files but clears metadata. | Pending |
| S9 | CLI install/uninstall | Symlink is created only when safe; foreign files are not replaced. | Pending |
| S10 | Show Welcome Again | Welcome window reopens from Settings and Help. | Pending |

### Finder extension

| ID | Check | Expected | Status |
| --- | --- | --- | --- |
| F1 | Register extension | Open the Release app once; `pluginkit -m -i com.sid.newfilecreation2.finder` lists it. | Pending |
| F2 | Enable extension | System Settings › General › Login Items & Extensions › Finder Extensions shows it enabled. | Pending |
| F3 | Toolbar menu | Finder toolbar shows New File with enabled templates. | Pending |
| F4 | Context menu | Right-click in a folder shows the same template menu. | Pending |
| F5 | Instant create | Creates in the targeted folder with default naming and uniqueness. | Pending |
| F6 | Ask for a name | Alert accepts a base name and creates there. | Pending |
| F7 | Add as Template | Selected Finder items open the app URL scheme and are added. | Pending |
| F8 | Disabled/favorite/category options | Menus reflect Settings changes on the next open. | Pending |
| F9 | Sandbox fallback | Direct copy denial falls back to `newfilecreation2://create` in the app. | Pending |
| F10 | Spanish Finder UI | Menu titles and alerts appear in Spanish with a Spanish system language. | Pending |

### CLI and localization

| ID | Check | Expected | Status |
| --- | --- | --- | --- |
| C1 | Installed symlink | `~/.local/bin/nfc` points inside the app bundle; `which nfc` works. | Pending |
| C2 | App not running | All CLI commands work headlessly. | Pending |
| C3 | Shell completion | zsh and bash scripts load without syntax errors. | Pending |
| C4 | Man page | `man -l docs/nfc.1` renders; `scripts/install-cli.sh --man` installs it. | Pending |
| C5 | Spanish app | Launch with `-AppleLanguages '(es)'`; menus, labels, and alerts are Spanish. | Pending |
| C6 | CLI locale independence | `--json` keys and exit codes are unchanged under any system language. | Pending |

## Known gaps

- Finder extension enablement and menu interaction require manual confirmation. Automated UI scripting would need Accessibility permission and a stable Finder state.
- AppKit UI components are instantiated in-process; full app launch, screen layout, and OS-level mouse dragging still require a manual smoke test.
- `NSFilePromiseReceiver` cannot run outside a real drag session, so the promise tests validate the delegate contract and destination registration rather than the complete gesture.
- The real Desktop test is opt-in with `NFC_TEST_REAL_DESKTOP=1`; the external-volume test is skipped unless a writable external volume is mounted or `NFC_TEST_EXTERNAL_VOLUME` is set.
- Direct sandbox copy versus URL-scheme fallback must be observed in `Console.app` or the local log, because Finder does not display which path was used.
- VoiceOver behavior is implemented and labels are inspected by tests, but the full screen-reader experience is not part of automated verification.

## Regression checklist

Before tagging a release:

```bash
xcodegen generate
./scripts/test.sh
./scripts/test-cli.sh
./scripts/build.sh
./scripts/verify.sh --no-build
```

Then complete the manual A, L, Q, S, and F rows for any area touched by the change. Update this matrix when a check becomes automated or a known gap is closed.
