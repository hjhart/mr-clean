import XCTest
@testable import MrCleanCore

final class DesktopArchiverTests: XCTestCase {
    private var sandbox: URL!
    private var desktop: URL!
    private var archiveRoot: URL!
    private var archiver: DesktopArchiver!

    override func setUpWithError() throws {
        sandbox = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MrCleanTests-\(UUID().uuidString)", isDirectory: true)
        desktop = sandbox.appendingPathComponent("Desktop", isDirectory: true)
        archiveRoot = sandbox.appendingPathComponent("Previous Desktops", isDirectory: true)
        try FileManager.default.createDirectory(at: desktop, withIntermediateDirectories: true)
        archiver = DesktopArchiver(archiveRoot: archiveRoot, desktop: desktop)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: sandbox)
    }

    // MARK: - Helpers

    private func makeFile(_ name: String, contents: String = "hi") throws {
        try contents.write(to: desktop.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private func makeFolder(_ name: String) throws {
        try FileManager.default.createDirectory(
            at: desktop.appendingPathComponent(name),
            withIntermediateDirectories: true
        )
    }

    private func names(in url: URL) throws -> Set<String> {
        Set(try FileManager.default.contentsOfDirectory(atPath: url.path))
    }

    // MARK: - Tests

    func testArchiveMovesVisibleItemsAndLeavesHiddenOnesBehind() throws {
        try makeFile("notes.txt")
        try makeFile(".DS_Store")
        try makeFolder("Project")

        let result = try archiver.archive(at: Date(timeIntervalSince1970: 1_770_000_000))
        let archive = try XCTUnwrap(result.archive)

        XCTAssertEqual(result.moved.sorted(), ["Project", "notes.txt"])
        XCTAssertTrue(result.failures.isEmpty)
        XCTAssertEqual(archive.itemCount, 2)
        XCTAssertEqual(try names(in: archive.url), ["notes.txt", "Project"])
        XCTAssertEqual(try names(in: desktop), [".DS_Store"])
    }

    func testArchiveFolderIsNamedWithATimestamp() throws {
        try makeFile("notes.txt")
        let date = Date(timeIntervalSince1970: 1_770_000_000)

        let archive = try XCTUnwrap(try archiver.archive(at: date).archive)

        XCTAssertEqual(archive.url.lastPathComponent, Paths.archiveFolderName(for: date))
        XCTAssertTrue(archive.url.lastPathComponent.hasSuffix("-archived-desktop"))
        XCTAssertEqual(archive.url.deletingLastPathComponent().path, archiveRoot.path)
    }

    func testArchivingAnEmptyDesktopCreatesNothing() throws {
        let result = try archiver.archive()

        XCTAssertNil(result.archive)
        XCTAssertTrue(result.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: archiveRoot.path))
    }

    func testTwoArchivesInTheSameSecondDoNotCollide() throws {
        let date = Date(timeIntervalSince1970: 1_770_000_000)
        try makeFile("one.txt")
        let first = try XCTUnwrap(try archiver.archive(at: date).archive)
        try makeFile("two.txt")
        let second = try XCTUnwrap(try archiver.archive(at: date).archive)

        XCTAssertNotEqual(first.url, second.url)
        XCTAssertEqual(second.url.lastPathComponent, first.url.lastPathComponent + " 2")
        XCTAssertEqual(try names(in: first.url), ["one.txt"])
        XCTAssertEqual(try names(in: second.url), ["two.txt"])
    }

    func testRestorePutsItemsBackAndRemovesTheArchiveFolder() throws {
        try makeFile("notes.txt", contents: "keep me")
        try makeFolder("Project")
        let archive = try XCTUnwrap(try archiver.archive().archive)

        let result = try archiver.restore(archive)

        XCTAssertEqual(result.moved.sorted(), ["Project", "notes.txt"])
        XCTAssertTrue(result.failures.isEmpty)
        XCTAssertEqual(try names(in: desktop), ["notes.txt", "Project"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: archive.url.path))
        XCTAssertEqual(try String(contentsOf: desktop.appendingPathComponent("notes.txt")), "keep me")
    }

    func testRestoreDoesNotOverwriteANewerFileOfTheSameName() throws {
        try makeFile("notes.txt", contents: "old")
        let archive = try XCTUnwrap(try archiver.archive().archive)
        try makeFile("notes.txt", contents: "new")

        try archiver.restore(archive)

        XCTAssertEqual(try names(in: desktop), ["notes.txt", "notes 2.txt"])
        XCTAssertEqual(try String(contentsOf: desktop.appendingPathComponent("notes.txt")), "new")
        XCTAssertEqual(try String(contentsOf: desktop.appendingPathComponent("notes 2.txt")), "old")
    }

    func testRecentArchivesAreNewestFirstAndIgnoreStrangers() throws {
        let older = Date(timeIntervalSince1970: 1_770_000_000)
        let newer = older.addingTimeInterval(3600)
        try makeFile("one.txt")
        _ = try archiver.archive(at: older)
        try makeFile("two.txt")
        try makeFile("three.txt")
        _ = try archiver.archive(at: newer)
        try FileManager.default.createDirectory(
            at: archiveRoot.appendingPathComponent("Random Folder"),
            withIntermediateDirectories: true
        )

        let recents = archiver.recentArchives()

        XCTAssertEqual(recents.count, 2)
        XCTAssertEqual(recents.map(\.date), [newer, older])
        XCTAssertEqual(recents.map(\.itemCount), [2, 1])
    }

    func testRecentArchivesIsEmptyWhenTheRootDoesNotExist() {
        XCTAssertEqual(archiver.recentArchives().count, 0)
    }

    func testArchiveFolderNameRoundTripsThroughTheDateParser() {
        let date = Date(timeIntervalSince1970: 1_770_012_345)
        let name = Paths.archiveFolderName(for: date)

        let parsed = Paths.date(fromArchiveFolderName: name)

        XCTAssertEqual(parsed?.timeIntervalSince1970, date.timeIntervalSince1970.rounded(.down))
        XCTAssertNil(Paths.date(fromArchiveFolderName: "Random Folder"))
        XCTAssertNil(Paths.date(fromArchiveFolderName: "not-a-date-archived-desktop"))
    }
}
