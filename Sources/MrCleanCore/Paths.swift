import Foundation

/// Resolves where archives live and where they come from.
public enum Paths {
    public static let archiveFolderSuffix = "-archived-desktop"
    public static let archiveFolderName = "Previous Desktops"

    /// The local hostname, sanitised for use as a folder-name component.
    /// e.g. "Jamess-MacBook-Pro.local" → "jamess-macbook-pro"
    public static var machineName: String {
        var name = ProcessInfo.processInfo.hostName
        if name.hasSuffix(".local") { name = String(name.dropLast(6)) }
        name = name.lowercased()
        // Replace any character that isn't alphanumeric or hyphen with a hyphen.
        name = name.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == "-" ? String($0) : "-" }.joined()
        // Collapse runs of hyphens and strip leading/trailing ones.
        while name.contains("--") { name = name.replacingOccurrences(of: "--", with: "-") }
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return name.isEmpty ? "unknown" : name
    }

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

    public static func archiveFolderName(for date: Date, machine: String? = nil) -> String {
        let m = machine ?? machineName
        return timestamp(for: date) + "-" + m + archiveFolderSuffix
    }

    /// Parses the timestamp back out of an archive folder name.
    /// Works for both the new `{timestamp}-{machine}-archived-desktop` format
    /// and the legacy `{timestamp}-archived-desktop` format.
    public static func date(fromArchiveFolderName name: String) -> Date? {
        guard name.hasSuffix(archiveFolderSuffix) else { return nil }
        let timestampLength = 19  // "yyyy-MM-dd-HH-mm-ss"
        guard name.count >= timestampLength else { return nil }
        let stamp = String(name.prefix(timestampLength))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter.date(from: stamp)
    }

    /// Extracts the machine name from an archive folder name, or nil for legacy folders.
    public static func machine(fromArchiveFolderName name: String) -> String? {
        guard name.hasSuffix(archiveFolderSuffix) else { return nil }
        let timestampLength = 19
        // After the timestamp comes "-{machine}-archived-desktop"
        // Legacy format has no machine: name is exactly timestamp + suffix (36 chars)
        let withoutSuffix = String(name.dropLast(archiveFolderSuffix.count))
        guard withoutSuffix.count > timestampLength + 1 else { return nil }
        return String(withoutSuffix.dropFirst(timestampLength + 1))  // skip the "-"
    }
}
