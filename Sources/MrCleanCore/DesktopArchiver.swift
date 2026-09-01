import Foundation

public struct Archive: Identifiable, Hashable {
    public var url: URL
    public var date: Date
    public var itemCount: Int

    public var id: URL { url }

    public init(url: URL, date: Date, itemCount: Int) {
        self.url = url
        self.date = date
        self.itemCount = itemCount
    }
}

public struct ArchiveResult {
    public var archive: Archive?
    public var moved: [String]
    public var failures: [(name: String, error: String)]

    public var isEmpty: Bool { moved.isEmpty && failures.isEmpty }
}

public enum ArchiverError: LocalizedError {
    case cannotCreateArchiveRoot(String)
    case cannotCreateArchiveFolder(String)

    public var errorDescription: String? {
        switch self {
        case .cannotCreateArchiveRoot(let reason):
            return "Couldn't create the Previous Desktops folder: \(reason)"
        case .cannotCreateArchiveFolder(let reason):
            return "Couldn't create today's archive folder: \(reason)"
        }
    }
}

/// Moves the Desktop into a timestamped folder, and puts it back again.
public struct DesktopArchiver {
    public var archiveRoot: URL
    public var desktop: URL
    public var fileManager: FileManager

    public init(archiveRoot: URL, desktop: URL = Paths.desktop, fileManager: FileManager = .default) {
        self.archiveRoot = archiveRoot
        self.desktop = desktop
        self.fileManager = fileManager
    }

    /// Everything on the Desktop that a person can see.
    public func visibleDesktopItems() throws -> [URL] {
        let contents = try fileManager.contentsOfDirectory(
            at: desktop,
            includingPropertiesForKeys: [.isHiddenKey],
            options: [.skipsHiddenFiles]
        )
        // `.skipsHiddenFiles` misses `.localized` style leftovers on some systems.
        return contents
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    @discardableResult
    public func archive(at date: Date = Date()) throws -> ArchiveResult {
        let items = try visibleDesktopItems()
        guard !items.isEmpty else {
            return ArchiveResult(archive: nil, moved: [], failures: [])
        }

        do {
            try fileManager.createDirectory(at: archiveRoot, withIntermediateDirectories: true)
        } catch {
            throw ArchiverError.cannotCreateArchiveRoot(error.localizedDescription)
        }

        let destination = uniqueURL(in: archiveRoot, named: Paths.archiveFolderName(for: date))
        do {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        } catch {
            throw ArchiverError.cannotCreateArchiveFolder(error.localizedDescription)
        }

        var moved: [String] = []
        var failures: [(name: String, error: String)] = []
        for item in items {
            let target = uniqueURL(in: destination, named: item.lastPathComponent)
            do {
                try fileManager.moveItem(at: item, to: target)
                moved.append(item.lastPathComponent)
            } catch {
                failures.append((item.lastPathComponent, error.localizedDescription))
            }
        }

        // Nothing made it across — don't leave an empty folder behind.
        if moved.isEmpty {
            try? fileManager.removeItem(at: destination)
            return ArchiveResult(archive: nil, moved: [], failures: failures)
        }

        let archive = Archive(url: destination, date: date, itemCount: moved.count)
        return ArchiveResult(archive: archive, moved: moved, failures: failures)
    }

    /// Moves an archive's contents back onto the Desktop and removes the empty folder.
    @discardableResult
    public func restore(_ archive: Archive) throws -> ArchiveResult {
        let contents = try fileManager.contentsOfDirectory(
            at: archive.url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        var moved: [String] = []
        var failures: [(name: String, error: String)] = []
        for item in contents {
            let target = uniqueURL(in: desktop, named: item.lastPathComponent)
            do {
                try fileManager.moveItem(at: item, to: target)
                moved.append(item.lastPathComponent)
            } catch {
                failures.append((item.lastPathComponent, error.localizedDescription))
            }
        }

        if failures.isEmpty {
            try? fileManager.removeItem(at: archive.url)
        }
        return ArchiveResult(archive: archive, moved: moved, failures: failures)
    }

    public func recentArchives(limit: Int = 10) -> [Archive] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: archiveRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents
            .compactMap { url -> Archive? in
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isDirectory, let date = Paths.date(fromArchiveFolderName: url.lastPathComponent) else { return nil }
                let count = (try? fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ).count) ?? 0
                return Archive(url: url, date: date, itemCount: count)
            }
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }

    /// Appends " 2", " 3", … until the name is free.
    private func uniqueURL(in directory: URL, named name: String) -> URL {
        let candidate = directory.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: candidate.path) else { return candidate }

        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var suffix = 2
        while true {
            var next = "\(base) \(suffix)"
            if !ext.isEmpty { next += ".\(ext)" }
            let url = directory.appendingPathComponent(next)
            if !fileManager.fileExists(atPath: url.path) { return url }
            suffix += 1
        }
    }
}
