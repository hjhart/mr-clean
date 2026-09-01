import Foundation

/// Resolves where archives live and where they come from.
public enum Paths {
    public static let archiveFolderSuffix = "-archived-desktop"
    public static let archiveFolderName = "Previous Desktops"

    public static var desktop: URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }

    /// `~/Library/Mobile Documents/com~apple~CloudDocs`, whether or not it exists yet.
    public static var iCloudDriveRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
    }

    public static var isICloudDriveAvailable: Bool {
        FileManager.default.fileExists(atPath: iCloudDriveRoot.path)
    }

    /// iCloud Drive when it's turned on, otherwise the home folder.
    public static var defaultArchiveRoot: URL {
        let parent = isICloudDriveAvailable ? iCloudDriveRoot : FileManager.default.homeDirectoryForCurrentUser
        return parent.appendingPathComponent(archiveFolderName, isDirectory: true)
    }

    public static func timestamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter.string(from: date)
    }

    public static func archiveFolderName(for date: Date) -> String {
        timestamp(for: date) + archiveFolderSuffix
    }

    /// Parses the timestamp back out of an archive folder name.
    public static func date(fromArchiveFolderName name: String) -> Date? {
        guard name.hasSuffix(archiveFolderSuffix) else { return nil }
        let stamp = String(name.dropLast(archiveFolderSuffix.count))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter.date(from: stamp)
    }
}
