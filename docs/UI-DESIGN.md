# UI Design

New File Creation 2 is a native AppKit app designed around one idea: create a file where you are already working, with as little interruption as possible.

## Principles

1. **Create where you work.** Finder menus, the menu bar, and the library can all create immediately; no app switch is required.
2. **One click, no dead ends.** The default template and default name produce a file immediately. Naming is available through a save panel when needed.
3. **Never lose data.** Existing files are never overwritten. Removing a template requires confirmation and moves its file to Trash.
4. **Keyboard first, mouse friendly.** Search, arrow keys, Return, and standard macOS shortcuts cover the main flows.
5. **Native macOS.** Semantic colors, vibrancy, SF Symbols, Auto Layout, standard controls, dark mode, and accessibility.
6. **Progressive disclosure.** Common settings are visible; diagnostics and configuration tools live under Advanced.
7. **Quiet feedback.** A short toast, optional sound, and optional Finder reveal/select; no persistent notifications.

## Visual language

- **Materials:** source-list sidebar; card backgrounds from `controlBackgroundColor`; floating quick panel; standard window backgrounds.
- **Accent:** system accent color for selection, focus, checkboxes, and primary actions. Brand color is limited to the icon and welcome illustration.
- **Typography:** system font. Window title via the toolbar; section headings 13 pt semibold; body 13 pt; secondary metadata 11 pt. No hardcoded font families.
- **Spacing:** 4/8/12/16/24/32 pt scale. Card grid uses 22 pt outer insets, 14 pt gaps, 168×150 pt cards.
- **Radii:** system controls as-is; cards and panels use the standard AppKit appearance.
- **Icons:** SF Symbols for actions and navigation; `NSWorkspace` file-type icons for templates. Finder menu icons are 16×16.
- **Dark mode:** semantic colors throughout (`labelColor`, `secondaryLabelColor`, `controlBackgroundColor`, `separatorColor`, `systemRedColor`); no fixed white/black fills.
- **Motion:** standard AppKit animation only; no custom motion that ignores Reduce Motion.
- **Accessibility:** labels and tooltips on icon-only controls, keyboard focus in the quick panel, source-list selection, standard alerts, and readable contrast in light/dark modes.

## Main library window

Default size 1040×660; minimum 780×480; resizable; centered; unified compact toolbar; tabbing disabled.

```
┌────────────────────────────────────────────────────────────────────────────┐
│  New File Creation 2   [New File] [New File…] [Add Template]  [Search] [▤] │
├──────────────────────┬─────────────────────────────────────┬───────────────┤
│ LIBRARY              │  All Templates                      │  Text File    │
│  ▣ All Templates  33 │  ┌────────┐ ┌────────┐ ┌────────┐   │  [file icon]  │
│  ★ Favorites      0 │  │ 📄     │ │ 📝     │ │ 🌐     │   │  TextFile.txt │
│  ↺ Recent         4 │  │ Text   │ │ Rich   │ │ HTML   │   │  DOCUMENTS    │
│                      │  │ File   │ │ Text   │ │ Page   │   │  Used 4 times │
│ CATEGORIES           │  └────────┘ └────────┘ └────────┘   │               │
│  Documents        7 │  ┌────────┐ ┌────────┐ ┌────────┐   │  [New File]   │
│  Spreadsheets     3 │  │ ...    │ │ ...    │ │ ...    │   │  [New File…]  │
│  Presentations    3 │  └────────┘ └────────┘ └────────┘   │  ☐ Favorite   │
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

- **New File** — create from the selected (or default) template in the default folder.
- **New File…** — create with a save panel so the name and location can be chosen.
- **Add Template** — multi-select files, packages, or folders to copy into the library.
- **Search** — live, case-insensitive search across display name, file name, category, and extension.
- **Inspector** — show/hide the right pane.

### Card grid

- Adaptive flow layout, one selection at a time.
- Each card shows a large file-type icon, display name, extension, and category; favorite and recency are reflected in the inspector and menus.
- Double-click or Return creates a file immediately.
- Drag a card to Finder to copy the template file. The drag is a standard file URL operation with a copy mask; Finder performs the copy and handles name collisions.
- Context menu: New File, New File…, Favorite/Remove Favorite, Reveal in Finder, Rename…, Remove Template….
- Empty state: “No Templates”, explanatory text, and **Add Template…**.
- Search with no results shows the empty state; the sidebar selection is preserved.

### Inspector

- Large file icon, display name, stored file name, category.
- Extension, use count, last-used date, and notes when present.
- **New File** and **New File…** buttons.
- Favorite and Enabled checkboxes.
- **Reveal Template** and **Remove Template…**.
- With no selection: a placeholder icon and “Select a template”.

### Menus

- **File:** New File (⌘N), New File… (⇧⌘N), Add Template… (⌘O), Quick New File… (⌘P), Open Library (⌘0), Close (⌘W).
- **Edit:** standard Undo/Redo/Cut/Copy/Paste/Select All; Search Templates (⌘F).
- **View:** Show/Hide Sidebar (⌃⌘S), Show/Hide Inspector (⌥⌘I), Reveal Selected Template (⌘R), Enter Full Screen (⌃⌘F).
- **Window:** Minimize, Zoom, Bring All to Front.
- **Help:** New File Creation 2 Help (⌘?), Open Templates Folder, Show Welcome.

The app menu includes About, Settings… (⌘,), Services, Hide/Hide Others/Show All, and Quit.

## Menu bar quick panel

- `NSStatusItem` with the `doc.badge.plus` symbol. Left-click toggles the visual quick panel, anchored below the status item; right-click opens a menu with quick panel, library, settings, add template, and quit.
- Floating 460×420 non-activating panel near the top of the screen (or below the status item when opened there); hides when it resigns key.
- Search field is focused automatically; the first result is selected.
- Rows show a 32×32 file icon, display name, category, extension, and a favorite star.
- Keyboard: ↑/↓ move, Return creates, Esc closes; double-click creates.
- Drag any row into a Finder window or another file-promise-aware drop target. The target chooses the folder; the file uses `defaultBaseName` plus the template extension, and the normal no-overwrite rules apply. The panel closes after a successful drop.
- The footer reads “↩ Create file    ⠿ Drag to Finder    esc Close”.
- If there are no matches: “No matching templates”.
- After creating with Return or double-click: the panel closes and the normal post-create settings apply (toast, reveal, open, sound). A drag lets the destination app decide what to do with the new file.

If **Show the menu bar icon** is disabled, the global shortcut still opens the quick panel. Both the Dock icon and menu bar icon cannot be disabled together; Settings prevents the last one from being turned off.

## Settings

A single non-modal 780×560 window with a source-list sidebar and detail panes. Changes apply immediately; there is no Save button. All destructive actions confirm first.

### General

- **New files:** default name, default template, default folder (with Choose…).
- **After creating:** reveal in Finder, open file, play sound, show a confirmation toast.
- **Application:** launch at login (`SMAppService`), show menu bar icon, show Dock icon, global shortcut.
- Shortcut presets: Control-Option-N, Control-Option-Space, Command-Shift-N, Option-Command-N, None.
- A note explains that the default name is shared by the app, Finder extension, and CLI, and that files are never overwritten.

### Templates

- Table of all templates: enabled checkbox, name, category, stored file.
- Buttons: Add…, Remove…, Set as Default.
- Removing removes metadata and moves the template file to Trash.
- Disabled templates do not appear in the app grid, quick panel, menu bar, or Finder menus.

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
- Show Welcome Again.
- Note: the app and CLI coordinate writes with a lock and atomic replacement; the Finder extension only reads config.

### About

- App icon, name, version.
- Tagline, MIT license/copyright, View License.
- Link back to the welcome window.

## Welcome window

- Shown on first launch and from Help/Advanced settings.
- App icon, headline, short description of Finder, menu bar, library, and CLI access.
- Finder extension status card.
- **Get Started** opens the library; **Open Settings** opens Settings.
- Closing the window marks onboarding complete.
- Reopen at any time with **Show Welcome** or **Show Welcome Again**.

## Finder menus

- Background/contextual menu and toolbar menu share the same template builder.
- **New File** submenu contains enabled templates, favorites first by default, optionally grouped by category, with 16×16 file-type icons.
- Items are titled “New <Template Name>”.
- **Add as Template** appears for selected items and the toolbar menu.
- Creating from Finder uses the targeted folder; for selected files, the containing folder; for a selected folder, that folder.
- Default behavior is instant creation. If **Ask for a name** is enabled, a small alert asks for a base name.
- If the sandbox denies a direct copy, the extension opens the app URL scheme and the non-sandboxed app performs the copy.
- Empty library: a disabled “No Templates” item.

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

- **No templates:** grid empty state with Add Template…; Finder shows “No Templates”; quick panel shows “No matching templates”.
- **Missing template file:** creation reports a clear error and leaves no partial destination.
- **Unwritable destination:** error names the folder; Finder falls back to the app URL scheme.
- **Config load failure:** warning alert at launch with Continue; corrupt config is quarantined under `Backups/` and `config.json.bak` is preferred when valid.
- **Finder extension unavailable:** Settings explains how to open System Settings; app and CLI creation remain available.
- **CLI install conflict:** if `~/.local/bin/nfc` is not a managed symlink, the app refuses to replace it and explains why.

## Localization

- UI strings are looked up through `NFLocalizedString`, with English strings as keys.
- English and Spanish `.strings` files ship in both the app and Finder extension bundles.
- The CLI’s human output is English in v2.0; JSON keys and error codes are locale-independent.
- Dynamic category titles are localized at display time while the stored category remains the stable English identifier.
- The XCTest suite checks that English and Spanish have identical key sets and no empty values.

## What is intentionally absent

- Touch Bar support (discontinued hardware).
- A Today widget (WidgetKit would require a Swift target; future work).
- iCloud zip sync, accounts, telemetry, and network access.
- A login helper app (`SMAppService.mainApp` is used instead).
- A custom-drawn UI toolkit; everything is standard AppKit.
