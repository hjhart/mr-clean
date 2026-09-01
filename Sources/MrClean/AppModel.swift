import AppKit
import Combine
import Foundation
import MrCleanCore
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    private enum Key {
        static let archiveRootPath = "archiveRootPath"
        static let revealAfterArchive = "revealAfterArchive"
    }

    @Published private(set) var recentArchives: [Archive] = []
    @Published private(set) var desktopItemCount: Int = 0
    @Published private(set) var statusLine: String = "Nothing archived yet"
    @Published private(set) var isWorking = false

    @Published var archiveRoot: URL {
        didSet {
            defaults.set(archiveRoot.path, forKey: Key.archiveRootPath)
            refresh()
        }
    }

    @Published var revealAfterArchive: Bool {
        didSet { defaults.set(revealAfterArchive, forKey: Key.revealAfterArchive) }
    }

    private let defaults: UserDefaults
    private var desktopWatcher: FolderWatcher?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let saved = defaults.string(forKey: Key.archiveRootPath), !saved.isEmpty {
            self.archiveRoot = URL(fileURLWithPath: saved, isDirectory: true)
        } else {
            self.archiveRoot = Paths.defaultArchiveRoot
        }
        self.revealAfterArchive = defaults.object(forKey: Key.revealAfterArchive) as? Bool ?? false
        refresh()
        desktopWatcher = FolderWatcher(url: Paths.desktop) { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
    }

    var archiver: DesktopArchiver { DesktopArchiver(archiveRoot: archiveRoot) }

    var isUsingICloud: Bool {
        archiveRoot.path.hasPrefix(Paths.iCloudDriveRoot.path)
    }

    /// Shown in Settings when archives would land outside iCloud Drive.
    var iCloudWarning: String? {
        guard !isUsingICloud else { return nil }
        if Paths.isICloudDriveAvailable {
            return "Archives are going to a local folder, so they won't sync."
        }
        return "iCloud Drive is turned off for this Mac, so archives are going to a local folder and won't sync. Turn on iCloud Drive in System Settings › Apple Account › iCloud, then point Mr Clean at it."
    }

    var archiveRootDisplayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if archiveRoot.path == Paths.iCloudDriveRoot.path || archiveRoot.path.hasPrefix(Paths.iCloudDriveRoot.path + "/") {
            return "iCloud Drive" + archiveRoot.path.dropFirst(Paths.iCloudDriveRoot.path.count)
        }
        if archiveRoot.path.hasPrefix(home + "/") {
            return "~" + archiveRoot.path.dropFirst(home.count)
        }
        return archiveRoot.path
    }

    func refresh() {
        desktopItemCount = (try? archiver.visibleDesktopItems().count) ?? 0
        recentArchives = archiver.recentArchives()
        if let latest = recentArchives.first {
            statusLine = "Last archive: \(latest.itemCount) item\(latest.itemCount == 1 ? "" : "s") · \(Self.relativeDate(latest.date))"
        } else {
            statusLine = "Nothing archived yet"
        }
    }

    func archiveDesktop() {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            let result = try archiver.archive()
            guard let archive = result.archive else {
                if result.failures.isEmpty {
                    presentInfo("Your Desktop is already clean", body: "There's nothing to archive.")
                } else {
                    presentFailures(result.failures, verb: "archive")
                }
                refresh()
                return
            }

            refresh()
            if !result.failures.isEmpty {
                presentFailures(result.failures, verb: "archive")
            }
            if revealAfterArchive {
                reveal(archive)
            }
        } catch {
            presentError(error)
        }
    }

    func restore(_ archive: Archive) {
        guard !isWorking else { return }
        let alert = NSAlert()
        alert.messageText = "Put this desktop back?"
        alert.informativeText = "\(archive.itemCount) item\(archive.itemCount == 1 ? "" : "s") from \(Self.longDate(archive.date)) will move back onto your Desktop."
        alert.addButton(withTitle: "Restore")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        isWorking = true
        defer { isWorking = false }
        do {
            let result = try archiver.restore(archive)
            refresh()
            if !result.failures.isEmpty {
                presentFailures(result.failures, verb: "restore")
            }
        } catch {
            presentError(error)
        }
    }

    func reveal(_ archive: Archive) {
        NSWorkspace.shared.activateFileViewerSelecting([archive.url])
    }

    func openArchiveRoot() {
        try? FileManager.default.createDirectory(at: archiveRoot, withIntermediateDirectories: true)
        NSWorkspace.shared.open(archiveRoot)
    }

    func chooseArchiveRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use Folder"
        panel.message = "Choose where Mr Clean should keep archived desktops."
        panel.directoryURL = FileManager.default.fileExists(atPath: archiveRoot.path)
            ? archiveRoot
            : archiveRoot.deletingLastPathComponent()

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        archiveRoot = url
    }

    func resetArchiveRootToDefault() {
        archiveRoot = Paths.defaultArchiveRoot
    }

    // MARK: - Launch at login

    var launchesAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                presentError(error)
            }
            objectWillChange.send()
        }
    }

    // MARK: - Alerts

    private func presentInfo(_ title: String, body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = .informational
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Mr Clean hit a problem"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func presentFailures(_ failures: [(name: String, error: String)], verb: String) {
        let detail = failures.prefix(8).map { "• \($0.name) — \($0.error)" }.joined(separator: "\n")
        let extra = failures.count > 8 ? "\n…and \(failures.count - 8) more." : ""
        presentInfo(
            "Couldn't \(verb) \(failures.count) item\(failures.count == 1 ? "" : "s")",
            body: detail + extra
        )
    }

    // MARK: - Formatting

    static func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func longDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
