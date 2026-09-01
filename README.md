# Mr Clean

A macOS menu bar app that sweeps your Desktop into a timestamped folder in iCloud Drive, so
your Desktop stays empty but nothing is ever lost.

Click **Archive Desktop** in the menu bar and everything visible on your Desktop moves to:

```
~/Library/Mobile Documents/com~apple~CloudDocs/Previous Desktops/2026-09-01-09-22-57-archived-desktop/
```

(that's `iCloud Drive/Previous Desktops/` in Finder)

## This is a clone of Mr Tidy

There used to be a small Mac utility called **Mr Tidy** ([getmrtidy.com](http://getmrtidy.com/),
now offline) with exactly one good idea: rather than making you file your Desktop clutter, it
swept the whole thing into a folder stamped with the date and time. Your Desktop was empty a
second later, and every previous Desktop was still sitting there in order if you ever needed
something back.

Mr Tidy stopped working after OS X El Capitan and was never updated. Mr Clean is a from-scratch
rebuild of that idea for current macOS, in Swift and SwiftUI, with two changes:

- **Archives go to iCloud Drive by default**, so your previous Desktops sync across your Macs
  instead of piling up on one disk.
- **Archives can be restored** — pick one from the menu and its contents move back onto the
  Desktop.

No affiliation with the original Mr Tidy or its author; none of its code was used. This is a
reimplementation of a behaviour, written because the original no longer runs.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+ or the Command Line Tools, for the Swift compiler — check with `swift --version`

## Build and install

```bash
git clone https://github.com/hjhart/mr-clean.git
cd mr-clean
./Scripts/build-app.sh --install
```

`build-app.sh` compiles a release build, assembles `dist/Mr Clean.app` (Info.plist, generated
icon, ad-hoc code signature), and with `--install` copies it to `/Applications` and launches it.
Drop `--install` to build into `dist/` only and move the app yourself.

Because the app is ad-hoc signed rather than notarized, the first launch from `/Applications`
may need a right-click › **Open** to get past Gatekeeper.

The first archive triggers a macOS permission prompt for Desktop access — allow it, or the
move fails with "operation not permitted". If you miss the prompt, grant it under
**System Settings › Privacy & Security › Files and Folders › Mr Clean**.

To uninstall: quit from the menu bar, then delete `/Applications/Mr Clean.app`. Your archives
stay where they are.

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

## License

MIT — see [LICENSE](LICENSE).
