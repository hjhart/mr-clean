# Mr Clean

A macOS menu bar app that sweeps your Desktop into a timestamped folder in iCloud Drive, so
your Desktop stays empty but nothing is ever lost. A modern rebuild of the old
[Mr Tidy](http://getmrtidy.com/), which stopped at El Capitan.

Click **Archive Desktop** in the menu bar and everything visible on your Desktop moves to:

```
~/Library/Mobile Documents/com~apple~CloudDocs/Previous Desktops/2026-09-01-09-22-57-archived-desktop/
```

(that's `iCloud Drive/Previous Desktops/` in Finder)

## Install

```bash
./Scripts/build-app.sh --install
```

That builds `dist/Mr Clean.app`, copies it to `/Applications`, and launches it. Drop the
`--install` flag to just build into `dist/`.

The first archive triggers a macOS permission prompt for Desktop access — allow it, or the
move fails with "operation not permitted". If you miss the prompt, grant it under
**System Settings › Privacy & Security › Files and Folders › Mr Clean**.

## Menu

| Item | What it does |
| --- | --- |
| **Archive Desktop (n items)** | Moves every visible Desktop item into a new timestamped folder. ⇧⌘A while the menu is open. |
| **Previous Desktops ▸** | The last 10 archives; each one can be opened in Finder or restored back to the Desktop. |
| **Open Previous Desktops Folder** | Opens the archive root in Finder. |
| **Settings…** | Archive location, reveal-after-archive, launch at login. |

## Behaviour

- **Hidden files stay put.** `.DS_Store` and friends are left on the Desktop.
- **Nothing is overwritten.** Name clashes get ` 2`, ` 3`, … on both archive and restore.
- **An empty Desktop is a no-op.** No empty folder gets created.
- **Per-item failures are reported, not swallowed.** If three files are locked, the other
  items still move and you get a list of what didn't.
- **Restore** moves an archive's contents back to the Desktop and deletes the now-empty
  archive folder — but only if every item made it back.

## iCloud Drive

The default archive location is `iCloud Drive/Previous Desktops`. If iCloud Drive is turned
off on this Mac (no `~/Library/Mobile Documents`), Mr Clean falls back to
`~/Previous Desktops` and says so in Settings. Turn iCloud Drive on under
**System Settings › Apple Account › iCloud › iCloud Drive**, then hit **Use Default** in
Settings to point it back at iCloud.

Any folder works — **Choose…** in Settings takes a Dropbox folder, an external drive, whatever.

## Development

```bash
swift build          # build
swift test           # 9 tests covering archive, restore, collisions, parsing
swift run MrClean    # run without bundling (menu bar icon appears; no Dock icon)
```

Layout:

- `Sources/MrCleanCore/` — file-moving logic, path resolution, folder watching. No UI, fully tested.
- `Sources/MrClean/` — SwiftUI `MenuBarExtra`, settings window, alerts.
- `Scripts/build-app.sh` — assembles and ad-hoc-signs the `.app` bundle.
- `Scripts/make-icon.swift` — renders the app icon from an SF Symbol at build time.

**Launch at login** uses `SMAppService`, which needs the app to live in `/Applications`.
Toggle it from Settings after installing.
