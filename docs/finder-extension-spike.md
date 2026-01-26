# Finder Sync Extension: Sandbox and Read-Only Config Notes

This note records the Finder Sync design, the sandbox constraints specific to an ad-hoc signed local build, and the manual checks still required before the Finder integration can be called verified.

## Goal

The Finder extension (`com.sid.newfilecreation2.finder`, principal class `NFCFinderSync`) should:

1. Add a **New File** template menu to Finder’s toolbar and contextual menus.
2. Add **Add as Template** for selected Finder items.
3. Create files in the targeted Finder folder using the shared default name and uniqueness rules.
4. Read templates and settings from the same support folder as the app and `nfc`.
5. Never write `config.json`.

## Constraints

- The app is non-sandboxed and is distributed locally with ad-hoc signing (`CODE_SIGN_IDENTITY=-`).
- The extension is sandboxed, as required for a Finder Sync app extension.
- There is no Apple Developer Team ID, provisioning profile, or App Group in v2.0.
- The extension is read-only with respect to configuration. The app and CLI are the only writers.
- The extension must not require the app to be running to build its menus.
- No network access, analytics, or third-party dependencies.

## Entitlements

`NewFileCreation2Finder/NewFileCreation2Finder.entitlements` contains:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.temporary-exception.files.home-relative-path.read-only</key>
<array>
    <string>/Library/Application Support/New File Creation 2/</string>
</array>
```

The home-relative read-only exception is the narrowest way to let the sandboxed menu builder read `config.json` and resolve template file names without an App Group.

An absolute-path exception was present during early development:

```xml
<key>com.apple.security.temporary-exception.files.absolute-path.read-only</key>
<array>
    <string>/Library/Application Support/New File Creation 2/</string>
</array>
```

It was removed. The path is root-relative (`/Library/...`), not the current user’s home (`~/Library/...`), and the home-relative exception already expresses the intended scope. Keeping both would have granted a broader and misleading exception.

`user-selected.read-write` allows the extension to act on URLs Finder hands it, including selected items. The direct creation path does not currently call `startAccessingSecurityScopedResource`; if a destination is still denied, the URL-scheme fallback handles it.

## Reading the real home directory

Inside a sandboxed extension, `NSHomeDirectory()` returns the extension container, not `/Users/<name>`. The config lives in the real home:

```
~/Library/Application Support/New File Creation 2/config.json
```

`NFCFinderSync` resolves the real home with:

```objc
struct passwd *pw = getpwuid(getuid());
NSString *home = pw ? [NSString stringWithUTF8String:pw->pw_dir] : NSHomeDirectory();
```

The extension then appends `Library/Application Support/New File Creation 2/`.

`config.json` is read with `NSDataReadingMappedIfSafe` and decoded with `NSJSONSerialization`. The reader:

- Returns `nil` if the file is missing or not a dictionary.
- Rejects a `schemaVersion` newer than `NFCSchemaVersion`.
- Passes the dictionary to `NFConfig`, which fills missing settings from defaults.
- Never calls `NFConfigStore`, never takes the write lock, and never creates files in the support folder.

A config change posts a distributed notification (`com.sid.newfilecreation2.configchanged`). The extension observes it but does not cache anything; Finder asks for a fresh menu each time, and `menuForMenuKind:` re-reads the config. This avoids stale templates and avoids cross-process cache invalidation.

## Menu construction

`menuForMenuKind:` uses shared `NFFinderMenuBuilder` and the config settings:

| Setting | Effect |
| --- | --- |
| `includeNewFileInFinderMenu` | Show or hide the **New File** submenu. |
| `includeAddAsTemplate` | Show or hide **Add as Template**. Only for selected items and the toolbar menu. |
| `favoritesFirst` | Sort favorites before other templates. |
| `groupByCategory` | Put templates in category submenus. |
| `showFileIcons` | Use 16×16 file-type icons. |
| `finderCreationBehavior` | `instant`, or `ask` to show a base-name alert. |

Only enabled templates are included. If no templates are enabled, the **New File** submenu is omitted; with no other items, the extension returns `nil` rather than an empty menu. With an empty but enabled library, `NFFinderMenuBuilder` supplies a disabled **No Templates** item.

Titles use the localized `"New %@"` key, so the extension’s Spanish menu reads **Nuevo <plantilla>**.

The extension monitors `/` via `FIFinderSyncController.directoryURLs` so the menu is available in every Finder folder.

## Destination resolution

`destinationDirectoryForMenuKind:` follows Finder’s target:

- Toolbar/background menu: `targetedURL`.
- Contextual menu for one selected item: the item itself if it is a folder, otherwise its parent folder.
- Contextual menu for several selected items: the parent folder of the first selected item.
- A non-folder target falls back to its parent.

Creation uses `NFFileCreator` with `unique:YES`, so a name collision becomes `Untitled 2.ext`, never an overwrite. The base name comes from `defaultBaseName` (default `Untitled`), not the template display name.

## Sandbox fallback

The extension first attempts the copy itself. If `NFFileCreator` reports:

- `NFErrorDestinationNotWritable`, or
- `NFErrorTemplateUnreadable`,

the extension builds a `newfilecreation2://create?...` URL with the template ID, destination directory, base name, and `unique=1`, then opens it with `NSWorkspace`. The non-sandboxed app performs the copy and its normal post-create actions (toast, reveal, open, sound).

Other errors (for example, a missing template) are shown in an `NSAlert` and logged; they do not silently fall back.

**Add as Template** always uses the URL scheme (`newfilecreation2://add-template?path=...`), because adding a template writes to `config.json` and copies into `Templates/`, both of which belong to the app. `NFRequest` validates the scheme, host, and absolute paths before the app touches the filesystem.

## Registration and enablement

The extension is embedded at:

```
New File Creation 2.app/Contents/PlugIns/New File Creation 2 Finder.appex
```

Check registration:

```bash
pluginkit -m -i com.sid.newfilecreation2.finder
```

A leading `+` means enabled; `-` means registered but disabled. If nothing is listed, open the app once and check again.

Enable it either in:

**System Settings › General › Login Items & Extensions › Finder Extensions**

or from the command line while developing:

```bash
pluginkit -e use -i com.sid.newfilecreation2.finder
```

If macOS keeps choosing an older Debug copy, remove stale registrations or launch the Release app from `/Applications`, then re-check.

### Observed state (2026-11-15)

- The embedded extension is present in the Release app and passes `codesign --verify --strict`.
- `pluginkit -m -i com.sid.newfilecreation2.finder` lists the extension.
- It is **registered but not enabled** at the time of this note. `scripts/verify.sh` reports this as a warning, not a failure.
- A live Finder menu and a sandbox direct-copy versus fallback test have **not** been completed.

## Manual verification procedure

1. Build and install:

   ```bash
   ./scripts/build.sh
   ./scripts/install.sh --yes
   open "/Applications/New File Creation 2.app"
   ```

2. Open **System Settings › General › Login Items & Extensions › Finder Extensions** and enable **New File Creation 2 Finder**. Confirm:

   ```bash
   pluginkit -m -i com.sid.newfilecreation2.finder | head -1
   ```

   shows a leading `+`.

3. In Finder, open a writable test folder. Confirm the toolbar **New File** menu and the folder context menu list enabled templates. Create one and verify:
   - the file appears in the targeted folder;
   - the base name is `Untitled` (or the configured default);
   - a second create becomes `Untitled 2`;
   - the file content matches the template.

4. Change **Finder › Creation behavior** to **Ask for a name** in Settings, reopen the Finder menu, and confirm the alert creates the requested name.

5. Select a file in Finder and choose **Add as Template**. Confirm the app opens, the template is copied, and it appears in the library and menus.

6. Test the fallback: make the target folder writable but deny the extension by testing with a folder outside the extension’s sandbox access (for example, a location that requires user consent), or temporarily instrument the failure path. Confirm the app receives `newfilecreation2://create` and creates the file. Check `Console.app` for messages beginning `Finder extension`.

7. Switch the system language to Spanish, relaunch Finder, and confirm **Nuevo archivo**, **Añadir como plantilla**, and the creation alert are translated.

## Known risks and next steps

- **Home-relative temporary exception:** This is the critical unverified assumption. If Finder’s sandbox denies reads despite the entitlement, menus will be empty. The fallback cannot fix menu construction because the extension still needs the template list. Alternatives are a read-only copy in an App Group (requires a Team ID/provisioning) or a helper XPC service; neither is planned for v2.0.
- **Direct copy permission:** The extension may be allowed to read templates but denied writing the target folder. The URL-scheme fallback covers that case, and this is the expected behavior in many locations.
- **Stale registered builds:** Debug and Release copies share a bundle identifier. Launch the Release app from `/Applications` after installing, and remove stale copies if `pluginkit` resolves the wrong path.
- **No automated Finder UI test:** Enabling the extension and driving Finder menus requires manual steps or Accessibility-authorized UI scripting. The repository intentionally does not ship such a script.
- **Logging:** Finder extension `NSLog` output is visible in Console.app, not in the app’s own log file. Filter by the extension process name or the `NFCFinderSync` messages.

## Files

- `NewFileCreation2Finder/NFCFinderSync.m` — Finder Sync principal class.
- `NewFileCreation2Finder/Info.plist` — extension point and principal class.
- `NewFileCreation2Finder/NewFileCreation2Finder.entitlements` — sandbox and read-only exception.
- `NewFileCreation2Shared/Finder/NFFinderMenuBuilder.m` — shared menu and icon construction.
- `NewFileCreation2Shared/Requests/NFRequest.m` — URL-scheme validation and building.
- `scripts/verify.sh` — registration warning and bundle checks.
