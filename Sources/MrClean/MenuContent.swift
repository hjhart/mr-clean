import SwiftUI
import MrCleanCore

struct MenuContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(archiveTitle) {
            model.archiveDesktop()
        }
        .keyboardShortcut("a", modifiers: [.command, .shift])
        .disabled(model.isWorking)

        Text(model.statusLine)

        Divider()

        if model.recentArchives.isEmpty {
            Text("No previous desktops yet")
        } else {
            Menu("Previous Desktops") {
                ForEach(model.recentArchives) { archive in
                    Menu(label(for: archive)) {
                        Button("Open in Finder") { model.reveal(archive) }
                        Button("Restore to Desktop…") { model.restore(archive) }
                    }
                }
            }
        }

        Button("Open \(Paths.archiveFolderName) Folder") { model.openArchiveRoot() }

        Divider()

        Button("Settings…") {
            // Without this the Settings window opens behind whatever's frontmost.
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("Quit Mr Clean") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    private var archiveTitle: String {
        let count = model.desktopItemCount
        guard count > 0 else { return "Archive Desktop (empty)" }
        return "Archive Desktop (\(count) item\(count == 1 ? "" : "s"))"
    }

    private func label(for archive: Archive) -> String {
        "\(AppModel.longDate(archive.date)) — \(archive.itemCount) item\(archive.itemCount == 1 ? "" : "s")"
    }
}
