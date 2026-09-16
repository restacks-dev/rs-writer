import XCTest
#if SWIFT_PACKAGE
@testable import WriterCore
#else
@testable import RS_Writer
#endif

final class LibraryDiskTests: XCTestCase {
    private var directory: URL!
    private var disk: LibraryDisk!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        disk = LibraryDisk()
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testSavePreservesExternalChangesInOriginalAndLocalChangesInConflictCopy() async throws {
        let url = try await disk.create(in: directory, name: "Essay", text: "original")
        let baseline = try await disk.read(url)
        try Data("remote edits".utf8).write(to: url, options: .atomic)
        let result = try await disk.save("local edits", to: url, expected: baseline)
        XCTAssertTrue(result.conflict)
        XCTAssertNotEqual(result.url, url)
        XCTAssertEqual(try String(contentsOf: url), "remote edits")
        XCTAssertEqual(try String(contentsOf: result.url), "local edits")
    }

    func testNormalSaveAndIdenticalRemoteSaveDoNotCreateConflict() async throws {
        let url = try await disk.create(in: directory, name: "Essay", text: "original")
        let baseline = try await disk.read(url)
        let first = try await disk.save("updated", to: url, expected: baseline)
        let second = try await disk.save("updated", to: url, expected: baseline)
        XCTAssertFalse(first.conflict)
        XCTAssertFalse(second.conflict)
        XCTAssertEqual(try String(contentsOf: url), "updated")
    }

    func testDeletedDocumentIsNotSilentlyRecreated() async throws {
        let url = try await disk.create(in: directory, name: "Essay", text: "original")
        let baseline = try await disk.read(url)
        try FileManager.default.removeItem(at: url)
        do { _ = try await disk.save("local", to: url, expected: baseline); XCTFail("Must fail") }
        catch { XCTAssertFalse(FileManager.default.fileExists(atPath: url.path)) }
    }

    func testCreateAndRenameNeverOverwriteExistingFile() async throws {
        let first = try await disk.create(in: directory, name: "First", text: "keep")
        let second = try await disk.create(in: directory, name: "Second", text: "second")
        do { _ = try await disk.create(in: directory, name: "First", text: "oops"); XCTFail("Must fail") } catch {}
        do { _ = try await disk.rename(second, name: "First"); XCTFail("Must fail") } catch {}
        XCTAssertEqual(try String(contentsOf: first), "keep")
        XCTAssertEqual(try String(contentsOf: second), "second")
    }

    func testScanIncludesNestedMarkdownAndSkipsHiddenFilesAndSymlinks() async throws {
        try await disk.createFolder(in: directory, name: "Notes")
        _ = try await disk.create(in: directory.appendingPathComponent("Notes"), name: "Idea")
        try Data().write(to: directory.appendingPathComponent(".hidden.md"))
        try Data().write(to: directory.appendingPathComponent("image.png"))
        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("link.md"), withDestinationURL: directory.appendingPathComponent("Notes/Idea.md"))
        let snapshot = try await disk.scan(directory)
        XCTAssertEqual(snapshot.files.map(\.relativePath), ["Notes/Idea.md"])
        XCTAssertEqual(snapshot.folders, ["Notes"])
    }

    func testInvalidNamesAndNonUTF8AreRejected() async throws {
        for name in ["", "../outside", ".secret", "a/b", "a:b", "a\nb"] {
            XCTAssertThrowsError(try LibraryDisk.validName(name))
        }
        let url = directory.appendingPathComponent("invalid.md")
        try Data([0xff, 0xfe, 0xff]).write(to: url)
        do { _ = try await disk.read(url); XCTFail("Must fail") } catch {}
    }

    func testOutlineIgnoresFencedCodeAndUsesUTF16Offsets() {
        let text = "🙂\n# Intro\n```swift\n# Not a heading\n```\n## Next\n"
        let headings = TextAnalysis.headings(text)
        XCTAssertEqual(headings.map(\.title), ["Intro", "Next"])
        XCTAssertEqual(headings.first?.offset, 3)
        XCTAssertEqual(TextAnalysis.words("# Hallo, wereld! — 2026"), 3)
    }

    func testRecoveryRetainsBaselineAcrossRestartAndProtectsRemoteEdits() async throws {
        let url = try await disk.create(in: directory, name: "Recovered", text: "original")
        let baseline = try await disk.read(url)
        let encoded = try JSONEncoder().encode(RecoveryDraft(text: "unsaved draft", baseline: baseline))
        try Data("remote change while app is closed".utf8).write(to: url, options: .atomic)
        let restored = try JSONDecoder().decode(RecoveryDraft.self, from: encoded)
        let result = try await disk.save(restored.text, to: url, expected: restored.baseline)
        XCTAssertTrue(result.conflict)
        XCTAssertEqual(try String(contentsOf: url), "remote change while app is closed")
        XCTAssertEqual(try String(contentsOf: result.url), "unsaved draft")
    }

    func testUnicodeAndCRLFContentSurvivesSaveAndRename() async throws {
        let original = "# Ideeën 🙂\r\n\r\nEen café.\r\n"
        let url = try await disk.create(in: directory, name: "Ideeën 🙂", text: original)
        let baseline = try await disk.read(url)
        let updated = original + "Tweede alinea.\r\n"
        _ = try await disk.save(updated, to: url, expected: baseline)
        let renamed = try await disk.rename(url, name: "Nieuw idee")
        XCTAssertEqual(try Data(contentsOf: renamed), Data(updated.utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testUnavailableLibraryThrowsInsteadOfReturningAnEmptyLibrary() async throws {
        let missing = directory.appendingPathComponent("not-mounted")
        do { _ = try await disk.scan(missing); XCTFail("Must fail") } catch {}
    }
}
