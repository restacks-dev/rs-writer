import Foundation

// Compile against the real model without launching the app or using its preferences.
@main
@MainActor
struct WriterModelTests {
    static func main() async throws {
        let tests = Self()
        try await tests.testUnusableBookmarkPreservesDraftsAndRequestsAccessWithoutAlertOnEachLaunch()
        try await tests.testReselectionReplacesBookmarkAndNextLaunchRestoresLibrary()
        try await tests.testUnavailableDriveKeepsBookmarkAndFailedManualSelectionStillReportsError()
        try await tests.testFreshInstallShowsNormalWelcome()
        print("Passed 4 library-access model checks.")
    }

    private func expect(_ condition: @autoclosure () throws -> Bool, line: UInt = #line) throws {
        guard try condition() else {
            throw NSError(domain: "WriterModelTests", code: Int(line), userInfo: [NSLocalizedDescriptionKey: "Model check failed at line \(line)"])
        }
    }
    private func withLibrary(_ check: (UserDefaults, URL) async throws -> Void) async throws {
        let suite = "nl.rs.writer.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        try await check(defaults, directory)
    }

    func testUnusableBookmarkPreservesDraftsAndRequestsAccessWithoutAlertOnEachLaunch() async throws {
        try await withLibrary { defaults, directory in
            let bookmark = Data("unusable bookmark".utf8)
            let path = directory.appendingPathComponent("Draft.md").path
            let drafts = try JSONEncoder().encode([path: RecoveryDraft(text: "unsaved", baseline: Data("original".utf8))])
            defaults.set(bookmark, forKey: "libraryBookmark")
            defaults.set(drafts, forKey: "recoveryV2")
            for _ in 0..<2 {
                let model = WriterModel(defaults: defaults, startAutomatically: false)
                await model.restore()
                try expect(model.root == nil)
                try expect(model.error == nil)
                try expect(model.libraryAccessNeedsRenewal)
                try expect(model.recovery[path]?.text == "unsaved")
                try expect(defaults.data(forKey: "libraryBookmark") == bookmark)
                try expect(defaults.data(forKey: "recoveryV2") == drafts)
            }
        }
    }

    func testReselectionReplacesBookmarkAndNextLaunchRestoresLibrary() async throws {
        try await withLibrary { defaults, directory in
            let document = directory.appendingPathComponent("Essay.md")
            let contents = Data("# Keep my words\n".utf8)
            try contents.write(to: document)
            let broken = Data("broken".utf8)
            defaults.set(broken, forKey: "libraryBookmark")
            let model = WriterModel(defaults: defaults, startAutomatically: false)
            await model.restore()
            await model.useFolder(directory)
            try expect(model.error == nil)
            try expect(!model.libraryAccessNeedsRenewal)
            try expect(model.root == directory)
            try expect(model.text == String(decoding: contents, as: UTF8.self))
            try expect(defaults.data(forKey: "libraryBookmark") != nil)
            try expect(defaults.data(forKey: "libraryBookmark") != broken)
            try expect(Data(contentsOf: document) == contents)

            let restarted = WriterModel(defaults: defaults, startAutomatically: false)
            await restarted.restore()
            try expect(restarted.error == nil)
            try expect(!restarted.libraryAccessNeedsRenewal)
            try expect(restarted.root?.standardizedFileURL == directory.standardizedFileURL)
            try expect(restarted.text == model.text)
        }
    }

    func testUnavailableDriveKeepsBookmarkAndFailedManualSelectionStillReportsError() async throws {
        try await withLibrary { defaults, directory in
            let bookmark = Data("saved bookmark".utf8)
            defaults.set(bookmark, forKey: "libraryBookmark")
            let model = WriterModel(defaults: defaults, startAutomatically: false)
            let missing = directory.appendingPathComponent("disconnected")
            await model.useFolder(missing, restoring: true)
            try expect(model.libraryAccessNeedsRenewal)
            try expect(model.error == nil)
            try expect(defaults.data(forKey: "libraryBookmark") == bookmark)
            await model.useFolder(missing)
            try expect(model.error != nil)
            try expect(defaults.data(forKey: "libraryBookmark") == bookmark)
        }
    }

    func testFreshInstallShowsNormalWelcome() async throws {
        try await withLibrary { defaults, _ in
            let model = WriterModel(defaults: defaults, startAutomatically: false)
            await model.restore()
            try expect(model.root == nil)
            try expect(model.error == nil)
            try expect(!model.libraryAccessNeedsRenewal)
        }
    }
}
