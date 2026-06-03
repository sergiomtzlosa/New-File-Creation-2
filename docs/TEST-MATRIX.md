# Test Matrix

This document records how New File Creation 2 is verified. Automated suites cover the shared model, configuration store, naming, creation, URL handling, Finder menu composition and sorting, Today widget template loading, WidgetKit bundle layout, localization, the CLI, programmatic AppKit UI components, floating-panel presentation, the permanent menu bar item, and drag-and-drop file promises into custom windows and folders. An XCUITest target drives the real app through the quick panel, Settings, and Get Started flows. Manual checks cover OS-level drag gestures, Finder integration, real menu-bar interaction, adding widgets from the gallery, and distribution behavior.

## Environment

| Item | Value |
| --- | --- |
| macOS | 27.2.1 (Darwin 27.x), Apple silicon |
| Xcode | 27.2 |
| XcodeGen | 2.46 |
| Build | Ad-hoc signed, `CODE_SIGN_IDENTITY=-` |
| App | `build/New File Creation 2.app` (Release) |
| Test host | Debug app, XCTest bundle `NewFileCreation2Tests.xctest` |
| UI test runner | `NewFileCreation2UITests.xctest`, isolated `NFC_SUPPORT_DIR` |

## Automated suites

Run all automated checks with:

```bash
./scripts/test.sh       # XCTest, 103 tests
./scripts/test-cli.sh   # isolated end-to-end CLI checks
./scripts/verify.sh     # signing, bundle, resources, then both suites
xcodebuild -project NewFileCreation2.xcodeproj -scheme NewFileCreation2UI \
  -configuration Debug -derivedDataPath build/DerivedData \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=YES test
```

Last automated run: **2026-11-16**. XCTest: **103 executed, 1 skipped, 0 failed (~10 s)**. The skipped test is the external-volume drag test because no writable external volume was mounted (the mounted NTFS volume is not writable). Opt-in runs also passed with `NFC_TEST_REAL_DESKTOP=1` against the real Desktop and with `NFC_TEST_EXTERNAL_VOLUME` pointing at a temporary writable disk image. XCUITest: **5 passed, 0 failed**. CLI integration: **20 passed, 0 failed**. Release verification: **41 passed, 0 warnings, 0 failed**. `scripts/verify.sh --no-build --quick` reports the static bundle, entitlement, localization, and signature checks. The Finder context menu was also confirmed manually on the Desktop, in a Finder window, and on a mounted removable volume. The WidgetKit Simulator discovered all three widget families and rendered a timeline from the real config with the expected template links.

### XCTest

| Suite | Tests | What is covered |
| --- | ---: | --- |
| `NFModelTests` | 10 | Defaults, config round-trip, unknown settings, template round-trip, category inference, display-name heuristics, bounded/deduplicated recents, custom categories (trimmed, deduplicated, persisted), category removal moving templates to Other, sort-mode round-trip. |
| `NFConfigStoreTests` | 7 | First-load seeding, read-only snapshot without writes, revisioned updates, cancelled updates, serialized concurrent writers, corrupt-config quarantine and backup, config replacement, custom-store isolation. |
| `NFFileCreatorTests` | 7 | Default name and extension, no double extension, unique suffix behavior, non-unique conflicts, missing template/destination errors, exact destination uniqueness, content copy. |
| `NFFilePromiseProviderTests` | 5 | Default and sanitized promise names, UTI selection and fallback, directory promises, non-overwriting copy, write callbacks. |
| `NFSanitizeTests` | 7 | Path separators and control characters, leading punctuation, fallback name, length cap, valid names, unique destination helpers, extensions. |
| `NFRequestTests` | 7 | Quick/library requests, create request round-trip, add-template request round-trip, scheme and host rejection, relative/traversal path rejection, missing template. |
| `NFFinderMenuBuilderTests` | 7 | Enabled-only menus, favorites first, category submenus, empty placeholder, persisted sort modes, and ordering by name, category, and file type. |
| `NFFinderDestinationTests` | 7 | Desktop, targeted-folder, selected-item, and fallback destination resolution for Finder menu kinds. |
| `NFTodayTemplateSourceTests` | 3 | Enabled templates and default name, favorites-first ordering, persisted category/file-type sorts, missing or damaged config handled without writing. |
| `NFCLITests` | 8 | Option parsing (values, flags, combined short flags, `--`), unknown/missing values, resolver by ID/name/normalized name, unique prefix, default selection, ambiguity, missing references. |
| `NFCUITests` | 4 | Main-menu search/reveal/full-screen shortcuts, core File menu commands, bundled README for Help, menu-bar accessory policy with no Dock icon. |
| `NFLocalizationTests` | 7 | 28-language key parity, no blank values, placeholder preservation, product-name preservation, Finder-specific translations, quick-panel drag hint, missing-key fallback. |
| `NFCUIComponentTests` | 16 | Main menu; floating three-pane library panel and toolbar; sidebar filters and custom categories; grid search/sort/selection/empty state; search field placement in the content column; context menu commands; collection card rendering and double-click; inspector metadata and commands; quick-panel rows, search, drag hint, app-icon Get Started button, gear, quit button, and Return; status-item menu, Get Started item, and permanent visibility; six Settings panes (including Help) with icons, floating panel style, adaptive window sizes, sort popup, category removal, sound name, and category assignment; Get Started fitted height, panel actions, aside resize, and callbacks; toast message and action; configured post-create sound; menu bar persists after the library closes. |
| `NFCDragAndDropTests` | 8 | Quick-panel file promises into a Finder-style folder, a custom promise-aware window, and a desktop-style folder; grid file-URL drops into a custom drop window; opt-in real Desktop drop; opt-in external-volume drop; missing-template drag rejection; no-overwrite behavior and metadata updates; configured sound after promise completion. |

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

### XCUITest end-to-end suite

`NewFileCreation2UI.xcscheme` launches the real Debug app with an isolated `NFC_SUPPORT_DIR` and `NFC_UI_TEST_OPEN_QUICK_PANEL=1`. The suite covers:

1. Quick panel opens; the title is centered between the close button and the gear; the gear closes the panel and opens Settings; closing Settings does not quit the menu-bar app.
2. The app icon left of the gear opens Get Started; the Get Started inspector aside widens the window without changing its fitted height, then collapses back to the original width.
3. The library search field stays below the toolbar and inside the content column, clear of the sidebar and inspector, including at the minimum window width.
4. The Settings Help tab resizes the window, shows the Help actions, and “Show Get Started” opens Get Started.
5. The README screenshot test opens the quick panel, library, and Settings on the primary display, selects a template, and writes the three app PNGs.

Screenshots are attached to each test and written to the runner’s temporary folder. The README app images are produced by `testCaptureReadmeScreenshots`; run it with `-only-testing:NewFileCreation2UITests/NFCApplicationUITests/testCaptureReadmeScreenshots` and copy the three PNGs into `docs/images/`. `scripts/render-readme-presentation.py` composes `docs/images/new-file-creation-2-presentation.png` from those captures, the app icon, and the widget image. The widget image is produced by `scripts/render-readme-widget.sh` from the real SwiftUI widget view. If a `com.apple.UserNotificationCenter` permission dialog blocks clicks, run `killall UserNotificationCenter` before the suite.


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
| Today extension signature | `codesign --verify --strict` |
| WidgetKit extension signature | `codesign --verify --strict` |
| `nfc` signature | `codesign --verify --strict` |
| Hardened runtime | app, Finder extension, Today extension, WidgetKit extension, and `nfc` |
| `nfc` executable | executable bit and path |
| Finder extension embedded | `.appex` exists under `Contents/PlugIns` |
| Today extension embedded | `.appex` exists under `Contents/PlugIns` |
| WidgetKit extension embedded | `.appex` exists under `Contents/PlugIns` |
| App / Finder / Today / Widget plists | `plutil -lint` |
| Version | `CFBundleShortVersionString == 2.0.0` |
| Bundle identifiers | app, Finder extension, Today extension, WidgetKit extension |
| Finder principal class | `NFCFinderSync` |
| WidgetKit extension point | `com.apple.widgetkit-extension` |
| URL scheme | `newfilecreation2` |
| Localization resources | all 28 `lproj` folders in the app, Finder, Today, and WidgetKit bundles |
| Localization parity | matching keys, non-empty values, placeholders, and preserved product name |
| Bundled templates | at least 30 files under `Resources/Templates` |
| App icon | `AppIcon.icns` present |
| Finder registration | `pluginkit -m -i com.sid.newfilecreation2.finder` |
| WidgetKit registration | `pluginkit -m -i com.sid.newfilecreation2.widget` |
| Sandbox entitlements | Finder, Today, and WidgetKit extensions declare App Sandbox |

## Manual test matrix

These checks are not fully automated in the repository. Run them after UI or Finder changes, or before a release. Rows marked **Automated** have in-process XCTest coverage but still merit an OS-level smoke test when permissions allow.

### App launch and first run

| ID | Check | Expected | Status |
| --- | --- | --- | --- |
| A1 | Launch with an empty support folder | App starts silently with only the menu bar icon (no Dock icon or window); 33 templates are seeded; config is created. | Pending |
| A2 | Relaunch | Settings and template state persist; no window opens automatically; Get Started remains available from the menu bar menu and the quick-panel app icon. | Pending |
| A3 | Launch with corrupt `config.json` | Warning is shown; corrupt file is quarantined under `Backups/`; app remains usable. | Pending |
| A4 | Launch with newer `schemaVersion` | App refuses to downgrade and reports a clear error. | Pending |
| A5 | Quit and reopen while `nfc` changed config | App reloads templates and settings. | Pending |

### Library panel

| ID | Check | Expected | Status |
| --- | --- | --- | --- |
| L1 | Sidebar counts | All, Favorites, Recent, and category counts match `nfc list`. | Pending |
| L2 | Open Library from the menu bar | Opens a floating panel above normal windows; no Dock icon appears; closing it leaves the menu bar icon running. | Automated (panel style) |
| L3 | Search | Typing filters by display name, file name, category, and extension. | Pending |
| L4 | ⌘F | Focuses the search field in the content header. | Pending |
| L5 | Return | Creates from the selected template in the default folder. | Pending |
| L6 | Double-click a card | Creates immediately. | Pending |
| L7 | Drag a card to Finder | Copies the template file; Finder resolves collisions. | Automated (file URL) |
| L8 | Context menu | New File, New File…, Favorite, Reveal, Rename, Remove all work. | Pending |
| L9 | ⌘R | Reveals the selected template in Finder; disabled with no selection. | Pending |
| L10 | Inspector | Favorite, Enabled, Reveal, Remove, Create File, and Create with Name… reflect the selection. | Pending |
| L11 | Add Template | Multi-select files/packages/folders; all are copied and appear in the grid. | Pending |
| L12 | Empty library | Empty state appears with Add Template…; Finder shows “No Templates”. | Pending |

### Quick panel and menu bar

| ID | Check | Expected | Status |
| --- | --- | --- | --- |
| Q1 | Global shortcut | Control-Option-N opens the quick panel from another app. | Pending |
| Q2 | Search and arrows | Typing filters; ↑/↓ move selection; Return creates; Esc closes. | Pending |
| Q3 | No matches | “No matching templates” is shown; Return does nothing harmful. | Pending |
| Q4 | Left-click status icon | Toggles the visual quick panel anchored below the icon; rows show 32×32 icons, metadata, and the drag hint. | Pending |
| Q5 | Right-click status icon | Menu shows quick panel, New File templates, Add Template, Library, Get Started, Settings, About, Quit, and reloads the template list each time it opens. | Pending |
| Q5b | Quit button in the quick panel | The power button in the quick panel header quits the app; closing the panel does not. | Automated (component) |
| Q6 | Menu bar icon setting | Checkbox is shown on and disabled; the status item cannot be hidden. | Automated (settings and menu bar) |
| Q7 | Dock presence | The app never appears in the Dock or app switcher; there is no Dock-owned window. | Automated (LSUIElement and panel policy) |
| Q8 | Hand-edited `showMenuBarIcon=false` | Status item still appears and all floating panels remain reachable. | Automated (delegate) |
| Q9 | Drag a template row to Finder | A file-promise drop creates `defaultBaseName.ext` in the target folder; Finder resolves collisions; recent/last-folder metadata updates; the panel closes; the configured sound plays. | Automated (promise) |
| Q10 | Drag to another window | A file-promise-aware target such as TextEdit accepts the drop and writes a default-named copy; cancelling the drag leaves the panel usable. | Automated (mock window) |
| Q11 | Window level | Library, Settings, Get Started, and quick panel float above normal windows and remain visible when the app deactivates. | Automated (panel style) |

### Settings

| ID | Check | Expected | Status |
| --- | --- | --- | --- |
| S1 | Change default name | App, Finder, and CLI all use the new `defaultBaseName`. | Pending |
| S2 | Change default folder/template | New File uses the new values. | Pending |
| S3 | Post-create options | Reveal, open, configured sound, and toast behave as checked; drag/promise completion uses the same sound. | Automated (sound hook) |
| S4 | Launch at login | `SMAppService` registers; approval state is explained. | Pending |
| S5 | Global shortcut presets | Each preset registers; conflicts revert to the previous shortcut. | Pending |
| S6 | Templates pane | Add, remove, enable/disable, set default, assign category, create a custom category, remove a category (templates move to Other), and sort by name, category, or file type; removed files go to Trash. | Automated (category assignment, removal, and sorting) |
| S7 | Finder pane | Status text is accurate; Enable Extension works or opens System Settings. | Pending |
| S8 | Advanced export/import/reset | Round-trip works; reset keeps template files but clears metadata. | Pending |
| S9 | CLI install/uninstall | Symlink is created only when safe; foreign files are not replaced. | Pending |
| S10 | Show Get Started | Get Started reopens from the menu bar, the quick-panel app icon, and Settings › Help. | Automated (XCUITest) |
| S11 | Settings presentation | Opens as a floating utility panel with icons on all six tabs; no Dock icon appears. | Automated (panel style and tab icons) |
| S12 | Adaptive Settings size | General, Templates, Finder, Advanced, Help, and About each resize the window to their preferred size. | Automated (XCUITest Help resize) |
| S13 | Help tab | Explains the app, shortcuts, Finder, CLI, and menu-bar workflow; Show Get Started and Open Templates Folder work. | Automated (XCUITest) |
| S14 | Get Started aside | The inspector button widens the window and shows “At a glance” beside the content; collapsing restores the width. | Automated (XCUITest and component) |

### Finder extension

| ID | Check | Expected | Status |
| --- | --- | --- | --- |
| F1 | Register extension | Open the Release app once; `pluginkit -m -i com.sid.newfilecreation2.finder` lists it. | Verified 2026-11-16 (`+`, installed under `/Applications`) |
| F2 | Enable extension | System Settings › General › Login Items & Extensions › Finder Extensions shows it enabled. | Verified 2026-11-16 (`pluginkit -e use`, state `+`) |
| F3 | Toolbar menu | Finder toolbar shows New File with enabled templates. | Pending |
| F4 | Context menu | Right-click in a folder shows the same template menu. | Verified 2026-11-16 (Desktop and Finder window) |
| F5 | Instant create | Creates in the targeted folder with default naming and uniqueness, including the Desktop. | Pending |
| F6 | Ask for a name | Alert accepts a base name and creates there. | Pending |
| F7 | Add as Template | Selected Finder items open the app URL scheme and are added. | Pending |
| F8 | Disabled/favorite/category options | Menus reflect Settings changes on the next open. | Pending |
| F9 | Creation handoff | Template selection opens `newfilecreation2://create` in the non-sandboxed app; the extension context is used if `NSWorkspace` fails. | Pending |
| F10 | Localized Finder UI | Menu titles and alerts follow the system language, including Spanish, German, Japanese, and right-to-left Arabic. | Pending |
| F11 | External/removable volume | Right-clicking the background or items on a mounted external volume shows the same New File menu. | Verified 2026-11-16 (SEAGATE4, NTFS) |

### Today widget (legacy)

| ID | Check | Expected | Status |
| --- | --- | --- | --- |
| T1 | Add the widget | Notification Center shows **New File Creation 2 Today** in the widget gallery on macOS releases that still support `com.apple.widget-extension`. | Pending |
| T2 | Template list | The widget lists enabled templates in the configured sort order and updates after Settings changes. | Automated (source loading and sorting) |
| T3 | Drag to a folder | Dragging a template row to a Finder folder or the Desktop creates one default-named file without overwriting. | Pending |
| T4 | Drag to another app | A file-promise-aware app accepts the dragged template as a new file. | Pending |
| T5 | Missing or damaged config | The widget shows a clear empty state and does not write to the support folder. | Automated (source loading) |

### WidgetKit widget

| ID | Check | Expected | Status |
| --- | --- | --- | --- |
| W1 | Register extension | Open the installed app once; `pluginkit -m -i com.sid.newfilecreation2.widget` lists it with `+`. | Verified 2026-11-16 (`+`, installed under `/Applications`) |
| W2 | Add the widget | The macOS widget gallery shows **New File** for New File Creation 2 in small, medium, and large sizes. | Partially verified 2026-11-16 (WidgetKit Simulator discovered and rendered all three sizes) |
| W3 | Template list | The widget lists enabled templates, favorites first, in the configured sort order; opening Settings does not reorder unexpectedly. | Verified 2026-11-16 (simulator timeline contained the real templates in config order) |
| W4 | Create from a template | Clicking a template opens `newfilecreation2://create?template=…&unique=1`; the app creates the file in the default folder without overwriting. | Partially verified 2026-11-16 (rendered links inspected; click-through pending) |
| W5 | Header and empty state | The plus button opens the quick panel; with no templates or a damaged config, Open Settings opens Settings and no file is written. | Pending |
| W6 | Refresh after edits | Adding, enabling, disabling, or reordering templates refreshes the timeline when the app writes the config. | Pending |

### CLI and localization

| ID | Check | Expected | Status |
| --- | --- | --- | --- |
| C1 | Installed symlink | `~/.local/bin/nfc` points inside the app bundle; `which nfc` works. | Pending |
| C2 | App not running | All CLI commands work headlessly. | Pending |
| C3 | Shell completion | zsh and bash scripts load without syntax errors. | Pending |
| C4 | Man page | `man -l docs/nfc.1` renders; `scripts/install-cli.sh --man` installs it. | Pending |
| C5 | Localized app | Launch with `-AppleLanguages` for Spanish, German, Japanese, and Arabic; menus, labels, and alerts follow the selected language. | Pending |
| C6 | CLI locale independence | `--json` keys and exit codes are unchanged under any system language. | Pending |

## Known gaps

- Finder toolbar interaction, creating a file from the menu, and post-create alerts require manual confirmation; the Desktop, Finder-window, and external-volume menus were verified on 2026-11-16.
- AppKit UI components are instantiated in-process; full app launch, screen layout, and OS-level mouse dragging still require a manual smoke test. XCUITest covers the quick panel, Settings, and Get Started pointer flows.
- `NSFilePromiseReceiver` cannot run outside a real drag session, so the promise tests validate the delegate contract and destination registration rather than the complete gesture. The Today widget drag gesture still requires a manual check.
- The real Desktop test is opt-in with `NFC_TEST_REAL_DESKTOP=1`; the external-volume test is skipped unless a writable external volume is mounted or `NFC_TEST_EXTERNAL_VOLUME` is set. A mounted external volume can make the opt-in test take several minutes.
- Direct sandbox copy versus URL-scheme fallback must be observed in `Console.app` or the local log, because Finder does not display which path was used.
- Today widget extensions are deprecated on current macOS. The appex is embedded and its data source is tested, but the system may not surface it in Notification Center on every macOS release. The WidgetKit extension is the supported widget path; see the W rows.
- WidgetKit gallery placement, cross-process rendering, and clicking a template link are manual checks because the system owns the widget host.
- VoiceOver behavior is implemented and labels are inspected by tests, but the full screen-reader experience is not part of automated verification.

## Regression checklist

Before tagging a release:

```bash
xcodegen generate
./scripts/test.sh
./scripts/test-cli.sh
./scripts/build.sh
./scripts/verify.sh --no-build
xcodebuild -project NewFileCreation2.xcodeproj -scheme NewFileCreation2UI \
  -configuration Debug -derivedDataPath build/DerivedData \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=YES test
```

Then complete the manual A, L, Q, S, F, T, and W rows for any area touched by the change. Update this matrix when a check becomes automated or a known gap is closed.
