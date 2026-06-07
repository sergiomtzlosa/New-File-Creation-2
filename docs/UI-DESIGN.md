# UI Design

New File Creation 2 is a native AppKit app designed around one idea: create a file where you are already working, with as little interruption as possible.

## Principles

1. **Create where you work.** Finder menus, the menu bar, the library, the Today widget, and the WidgetKit widget can all create immediately; no app switch is required.
2. **One click, no dead ends.** The default template and default name produce a file immediately. Naming is available through a save panel when needed.
3. **Never lose data.** Existing files are never overwritten. Removing a template requires confirmation and moves its file to Trash.
4. **Keyboard first, mouse friendly.** Search, arrow keys, Return, and standard macOS shortcuts cover the main flows.
5. **Native macOS.** Semantic colors, vibrancy, SF Symbols, Auto Layout, standard controls, dark mode, and accessibility.
6. **Progressive disclosure.** Common settings are visible; diagnostics and configuration tools live under Advanced.
7. **Quiet feedback.** A short toast, optional sound, and optional Finder reveal/select; no persistent notifications.
8. **Menu bar only.** New File Creation 2 has no Dock icon and no Dock-owned window. Every window is a floating panel opened from the menu bar icon.

## Visual language

- **Materials:** source-list sidebar; card backgrounds from `controlBackgroundColor`; floating panels with standard window backgrounds.
- **Accent:** system accent color for selection, focus, checkboxes, and primary actions. Brand color is limited to the icon and welcome illustration.
- **Typography:** system font. Window title via the toolbar; section headings 13 pt semibold; body 13 pt; secondary metadata 11 pt. No hardcoded font families.
- **Spacing:** 4/8/12/16/24/32 pt scale. Card grid uses 22 pt outer insets, 14 pt gaps, 168×150 pt cards.
- **Radii:** system controls as-is; cards and panels use the standard AppKit appearance.
- **Icons:** SF Symbols for actions and navigation; `NSWorkspace` file-type icons for templates. Finder menu icons are 16×16.
- **Dark mode:** semantic colors throughout (`labelColor`, `secondaryLabelColor`, `controlBackgroundColor`, `separatorColor`, `systemRedColor`); no fixed white/black fills.
- **Motion:** standard AppKit animation only; no custom motion that ignores Reduce Motion.
- **Accessibility:** labels and tooltips on icon-only controls, keyboard focus in the quick panel, source-list selection, standard alerts, and readable contrast in light/dark modes.

## Library panel

A 1040×660 floating panel opened from **Open Library** in the menu bar menu (and from the app menu or URL scheme when the app is already active). Minimum 780×480; resizable; centered; unified compact toolbar; no minimize button and no tabbing. The panel floats above normal windows, stays open when the app deactivates, and closing it leaves the menu bar icon running.

```
┌────────────────────────────────────────────────────────────────────────────┐
│  New File Creation 2   [Create File] [Create with Name…]  [Search] [▤]     │
├──────────────────────┬─────────────────────────────────────┬───────────────┤
│ LIBRARY              │  All Templates                      │  Text File    │
│  ▣ All Templates  33 │  ┌────────┐ ┌────────┐ ┌────────┐   │  [file icon]  │
│  ★ Favorites      0 │  │ 📄     │ │ 📝     │ │ 🌐     │   │  TextFile.txt │
│  ↺ Recent         4 │  │ Text   │ │ Rich   │ │ HTML   │   │  DOCUMENTS    │
│                      │  │ File   │ │ Text   │ │ Page   │   │  Used 4 times │
│ CATEGORIES           │  └────────┘ └────────┘ └────────┘   │               │
│  Documents        7 │  ┌────────┐ ┌────────┐ ┌────────┐   │  [Create File]│
│  Spreadsheets     3 │  │ ...    │ │ ...    │ │ ...    │   │  [Create with │
│  Presentations    3 │  └────────┘ └────────┘ └────────┘   │  Name…]       │
│  Code             6 │                                     │  ☑ Enabled    │
│  Images           4 │                                     │  Reveal       │
│  Audio            1 │                                     │  Remove…      │
│  Video            1 │                                     │               │
│  Archives         1 │                                     │               │
│  Other            7 │                                     │               │
└──────────────────────┴─────────────────────────────────────┴───────────────┘
```

### Sidebar

- **Library:** All Templates, Favorites, Recent (with counts).
- **Categories:** Documents, Spreadsheets, Presentations, Code, Images, Audio, Video, Archives, Other; only categories present in the library are shown, with counts.
- Selecting a source filters the grid. Search applies within the current source.
- Group rows are non-selectable; the source list is expanded by default.

### Toolbar

- **Search** — live, case-insensitive search across display name, file name, category, and extension.
- **Create File** — create from the selected (or default) template in the default folder.
- **Create with Name…** — create with a save panel so the name and location can be chosen.
- **Add Template** — multi-select files, packages, or folders to copy into the library.
- **Inspector** — show/hide the right pane.

The search field is the first toolbar item, directly left of **Create File**, followed by flexible space and the **Inspector** toggle. It stays to the left of the inspector at every window width. ⌘F focuses this field and, if the item was removed through toolbar customization, re-inserts it at index 0.

### Card grid

- Adaptive flow layout, one selection at a time.
- Each card shows a large file-type icon, display name, extension, and category; favorite and recency are reflected in the inspector and menus.
- Double-click or Return creates a file immediately.
- Drag a card to Finder to copy the template file. The drag is a standard file URL operation with a copy mask; Finder performs the copy and handles name collisions.
- Context menu: Create in Default Folder, Choose Name and Location…, Favorite/Remove Favorite, Reveal in Finder, Rename…, Remove Template….
- Empty state: “No Templates”, explanatory text, and **Add Template…**. Search-empty state keeps the same actions without losing the current sidebar selection.
- Search with no results shows the empty state; the sidebar selection is preserved.

### Inspector

- Large file icon, display name, stored file name, category.
- Extension, use count, last-used date, and notes when present.
- **Create in Default Folder** and **Choose Name and Location…** buttons.
- Favorite and Enabled checkboxes.
- **Reveal Template** and **Remove Template…**.
- With no selection: a placeholder icon and “Select a template”.

### Menus

- **File:** New File (⌘N), New File… (⇧⌘N), Add Template… (⌘O), Quick New File… (⌘P), Open Library (⌘0), Close (⌘W).
- **Edit:** standard Undo/Redo/Cut/Copy/Paste/Select All; Search Templates (⌘F).
- **View:** Show/Hide Sidebar (⌃⌘S), Show/Hide Inspector (⌥⌘I), Reveal Selected Template (⌘R), Enter Full Screen (⌃⌘F).
- **Window:** Zoom, Bring All to Front.
- **Help:** New File Creation 2 Help (⌘?), Open Templates Folder, Show Get Started.

The app menu includes About, Settings… (⌘,), Services, Hide/Hide Others/Show All, and Quit.

## Menu bar quick panel

- `NSStatusItem` with the `doc.badge.plus` symbol. The status item is permanent and cannot be hidden. Left-click toggles the visual quick panel, anchored below the status item; right-click opens a menu with quick panel, New File templates, add template, library, Get Started, settings, about, and quit. The template list is rebuilt every time the menu opens, so changes from Settings or `nfc` appear immediately.
- Floating 460×420 panel near the top of the screen (or below the status item when opened there); hides when it resigns key.
- A trailing app icon, centered title, gear button, and power button sit in the header. The app icon closes the panel and opens Get Started; the gear closes the panel and opens Settings; the power button quits the app. All three icon-only controls have tooltips and accessibility labels.
- Search field is focused automatically; the first result is selected. The panel reloads the shared configuration when it opens, so new templates and category changes are visible without relaunching.
- Rows show a 32×32 file icon, display name, category, extension, and a favorite star.
- Keyboard: ↑/↓ move, Return creates, Esc closes; double-click creates.
- Drag any row into a Finder window or another file-promise-aware drop target. The target chooses the folder; the file uses `defaultBaseName` plus the template extension, and the normal no-overwrite rules apply. The panel closes after a successful drop.
- The footer reads “↩ Create file    ⠿ Drag to Finder    esc Close”.
- If there are no matches: “No matching templates”.
- After creating with Return or double-click: the panel closes and the normal post-create settings apply (toast, reveal, open, sound). A completed drag plays the same configured sound. A drag lets the destination app decide what to do with the new file.

The menu bar icon is always available and Settings disables its checkbox. The app has no Dock icon; every window is a floating panel.

## Settings

A floating utility panel opened from the menu bar menu, the quick panel gear, the app menu, or the URL scheme. It stays above normal windows, remains available when the app deactivates, and never appears as a Dock window. Six tabs carry SF Symbol icons: General, Templates, Finder, Advanced, Help, and About. The window resizes to a preferred size for each tab: General 680×620, Templates 780×620, Finder 680×600, Advanced 680×560, Help 720×640, About 560×460. Changes apply immediately; there is no Save button. All destructive actions confirm first.

### General

- **New files:** default name, default template, default folder (with Choose…).
- **After creating:** reveal in Finder, open file, play a sound, and choose the sound name from the system sound folders; show a confirmation toast.
- **Application:** launch at login (`SMAppService`), the permanent menu bar icon (checkbox shown on and disabled), and the global shortcut.
- Shortcut presets: Control-Option-N, Control-Option-Space, Command-Shift-N, Option-Command-N, None.
- A note explains that the default name is shared by the app, Finder extension, and CLI, and that files are never overwritten.

### Templates

- Table of all templates: enabled checkbox, name, category, stored file.
- Category popup assigns the selected template to a category, including custom categories. **Remove Category…** removes the selected custom category after confirmation and moves its templates to **Other**; the alert states how many templates will move.
- Inline **New category** field and **Add Category** button create a custom category and assign it to the selected template.
- **Sort by** popup orders templates by manual order, name, category, or file type. Category sorting groups by category name, then template name; file-type sorting compares extension, then display name. Favorites remain first where the UI promises it.
- Buttons: Add…, Remove…, Set as Default.
- Removing a template removes metadata and moves the template file to Trash.
- Disabled templates do not appear in the app grid, quick panel, menu bar, Finder menus, Today widget, or WidgetKit widget.

### Finder

- Extension status: enabled, disabled, not registered, or unavailable.
- **Enable Extension** attempts to enable it with `pluginkit -e use`; on failure, offers System Settings.
- **Open System Settings…** opens Login Items & Extensions.
- Menu options: include “New File”, include “Add as Template”, favorites first, group by category, show template icons.
- Creation behavior: create immediately or ask for a name.
- Note explains that changes apply the next time a Finder menu opens.

### Advanced

- Reveal Config, Export…, Import…, Reset Configuration….
- Open Templates Folder.
- **Command-line tool:** install/uninstall the `nfc` symlink, status, and PATH hint.
- Reveal Log.
- Show Get Started.
- Note: the app and CLI coordinate writes with a lock and atomic replacement; the Finder, Today, and WidgetKit extensions only read config.

### Help

- A short explanation of the app: reusable templates and local-only creation.
- Step-by-step workflows for the menu bar quick panel, Finder menus, the library, the CLI, and both widgets.
- Keyboard reference for ⌘N, ⇧⌘N, the global shortcut, Return, and Esc.
- **Show Get Started** opens the Get Started window; **Open Templates Folder** reveals the shared templates.
- Notes on enabling the Finder extension and using `nfc`.

### About

- App icon, name, version.
- Tagline, MIT license/copyright, View License.
- Link back to Get Started.

## Get Started window

- A floating panel opened from the menu bar menu, the quick-panel app icon, Settings › Help, or the app menu. The app launches silently with only the menu bar icon; no window is opened automatically.
- App icon, headline, and a short description of Finder, menu bar, library, CLI, Today widget, and WidgetKit widget access.
- Four feature rows: menu bar and global shortcut, Finder menus, `nfc`, and local-only privacy.
- **Open Template Library** opens the library panel; **Open Settings** opens Settings. Return triggers the primary action.
- An inspector button at the top-right opens an inline right-side aside titled “At a glance”: template count, quick-panel hints, drag hint, Return hint, and pointers to Settings › Templates, Finder, and Help, plus **Open Templates Folder**.
- The aside is part of the window rather than an overlay: opening it widens the window by 276 pt and reserves a 260 pt column, so it never covers the headline, feature rows, or buttons. Collapsing restores the original width without animation.
- The window measures its natural content height at startup instead of using a fixed tall frame, then uses the height measured at the minimum width as its minimum size. The result is a compact footer with a 24 pt bottom inset that still accommodates wrapped translations.
- Closing the panel marks onboarding complete. Reopen it at any time from the menu bar, the quick panel app icon, Settings › Help, or the app menu.

## Window behavior

- The app is an `LSUIElement` menu bar accessory. It has no Dock icon and no Dock-owned window at any point.
- The library, Settings, Get Started, and quick panel are all `NSPanel` subclasses that float above normal windows (`NSFloatingWindowLevel`), stay visible when the app deactivates, and are released only when the app quits.
- Windows are activated and keyed when opened from the menu bar icon. Closing one never quits the app; use **Quit New File Creation 2** in the menu bar menu.
- Panels can join all Spaces and remain available as full-screen auxiliaries. None of them can be minimized into a Dock tile.
- Open windows observe the shared config change notification: template rows, category lists, and template counts refresh when Settings, the CLI, or another process writes `config.json`. The quick panel and menu bar template list reload when opened.

## Finder menus

- Background/contextual menu and toolbar menu share the same template builder.
- **New File** submenu contains enabled templates, favorites first by default, optionally grouped by category, with 16×16 file-type icons.
- Items are titled “New <Template Name>”.
- **Add as Template** appears for selected items and the toolbar menu.
- Creating from Finder uses the targeted folder; for selected files, the containing folder; for a selected folder, that folder.
- Default behavior is instant creation. If **Ask for a name** is enabled, a small alert asks for a base name.
- The extension never writes the destination itself. Choosing a template opens `newfilecreation2://create` with `NSWorkspace`; if that fails, it asks its `NSExtensionContext` and then shows an error. The non-sandboxed app performs the copy.
- Creation targets the currently browsed folder, the selected item’s folder, or the Desktop as appropriate.
- Empty library: a disabled “No Templates” item.

## Today widget

- A legacy Notification Center Today extension (`com.apple.widget-extension`) embedded at `Contents/PlugIns/New File Creation 2 Today.appex`. Today extensions are deprecated on current macOS, so the widget may not be listed on every release; the app, Finder, CLI, and WidgetKit flows do not depend on it.
- 320×300 layout: app icon, “New File Creation 2”, drag hint, and a plain table of enabled templates.
- Rows use the same file-type icons, favorites-first ordering, and persisted name/category/file-type sorting as the rest of the app.
- Dragging a row uses `NFFilePromiseProvider`, so a Finder folder, the Desktop, or another file-promise-aware app writes one default-named file with the usual no-overwrite rules.
- Missing or damaged `config.json` shows “No templates to show”; the widget only reads the shared configuration and never writes to it.
- The widget reloads when Notification Center asks for its view and observes the shared config change notification.

## WidgetKit widget

- A modern WidgetKit extension (`com.apple.widgetkit-extension`) embedded at `Contents/PlugIns/New File Creation 2 Widget.appex`, for macOS releases that no longer register legacy Today extensions.
- Small: one column of four templates. Medium: two columns of three. Large: three columns of four. The grid is intentionally compact so template names remain legible at widget scale.
- Header: `doc.badge.plus` symbol, “New File”, and a plus button that opens the quick panel. Empty state: tray symbol, product name, and Open Settings.
- Each row is a `Link` to `newfilecreation2://create?template=<id>&unique=1`, using the same semantic file-type symbol and color as the rest of the app. Creating opens the app; the widget itself never writes files.
- Favorites-first and the persisted sort mode are honored. A five-minute timeline refresh and a `WidgetCenter` reload after observed config changes keep the list current.
- Uses `containerBackground(for: .widget)` on macOS 14+ and a plain gradient background on macOS 13. No custom motion or hardcoded light/dark fills.

## Keyboard shortcuts

| Context | Shortcut | Action |
| --- | --- | --- |
| Global | ⌃⌥N (default) | Open the quick panel |
| App | ⌘N | New File from selected template |
| App | ⇧⌘N | New File with save panel |
| App | ⌘O | Add Template… |
| App | ⌘P | Quick New File… |
| App | ⌘0 | Open Library |
| App | ⌘, | Settings |
| App | ⌘F | Focus search (Edit › Search Templates) |
| App | ⌃⌘S | Show/hide sidebar |
| App | ⌥⌘I | Show/hide inspector |
| App | ⌘R | Reveal selected template (View menu) |
| App | Return | Create from selected template |
| Quick panel | ↑/↓ | Move selection |
| Quick panel | Return | Create selected template |
| Quick panel | Esc | Close panel |
| Finder menu | Arrow keys/Return | Standard menu navigation |

The global shortcut is configurable only through the presets in Settings; arbitrary key combinations are validated by `NFShortcutCenter` but the UI intentionally stays small.

## Empty, loading, and error states

- **No templates:** grid empty state with Add Template…; Finder shows “No Templates”; quick panel shows “No matching templates”; the WidgetKit widget shows its Open Settings empty state.
- **Missing template file:** creation reports a clear error and leaves no partial destination.
- **Unwritable destination:** error names the folder; Finder falls back to the app URL scheme.
- **Config load failure:** warning alert at launch with Continue; corrupt config is quarantined under `Backups/` and `config.json.bak` is preferred when valid.
- **Finder extension unavailable:** Settings explains how to open System Settings; app and CLI creation remain available.
- **CLI install conflict:** if `~/.local/bin/nfc` is not a managed symlink, the app refuses to replace it and explains why.

## Localization

- UI strings are looked up through `NFLocalizedString`, with English strings as keys.
- All 28 languages from New File Creation v1 ship `.strings` files in the app, Finder extension, Today widget, and WidgetKit widget bundles: Arabic, Catalan, Danish, German, Greek, English, Spanish, Basque, Finnish, French, Galician, Hindi, Indonesian, Icelandic, Italian, Japanese, Korean, Malay, Norwegian Bokmål, Dutch, Polish, Portuguese (Portugal), Romanian, Russian, Swedish, Turkish, Simplified Chinese, and Traditional Chinese.
- Arabic is the right-to-left locale; AppKit mirrors the standard layout automatically.
- The product name “New File Creation 2” is never translated. “nfc” and technical tokens such as `config.json` are also preserved.
- The CLI’s human output is English in v2.0; JSON keys and error codes are locale-independent.
- Dynamic category titles are localized at display time while the stored category remains the stable English identifier.
- The XCTest and verification suites check that every language has the same keys as English, non-empty values, matching format placeholders, and the preserved product name.

## What is intentionally absent

- Touch Bar support (discontinued hardware).
- A Dock icon or Dock-owned main window; the app is menu-bar-only.
- iCloud zip sync, accounts, telemetry, and network access.
- A login helper app (`SMAppService.mainApp` is used instead).
- A custom-drawn UI toolkit; everything is standard AppKit.
