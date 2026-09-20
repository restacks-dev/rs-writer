import Foundation
import Combine

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
        try await tests.testSelectionUpdatesImmediatelyAndSavesThePreviousDocument()
        try await tests.testConflictSaveDoesNotBounceThePendingSelection()
        try await tests.testSaveFailureKeepsThePreviousDocumentAndDraft()
        try await tests.testReadFailureRestoresThePreviousSelection()
        print("Passed 8 library-access and document-selection model checks.")
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

    private func withDocuments(_ check: (WriterModel, URL, URL) async throws -> Void) async throws {
        try await withLibrary { defaults, directory in
            let first = directory.appendingPathComponent("First.md")
            let second = directory.appendingPathComponent("Second.md")
            try Data("first".utf8).write(to: first)
            try Data("second".utf8).write(to: second)
            defaults.set("First.md", forKey: "lastFile:\(directory.path)")
            let model = WriterModel(defaults: defaults, startAutomatically: false)
            await model.useFolder(directory, persist: false)
            // Use the same canonical URLs that Finder enumeration supplies to List.
            let firstFile = model.files.first { $0.relativePath == "First.md" }!
            let secondFile = model.files.first { $0.relativePath == "Second.md" }!
            try expect(model.selectedURL == firstFile.url)
            try await check(model, firstFile.url, secondFile.url)
        }
    }

    func testSelectionUpdatesImmediatelyAndSavesThePreviousDocument() async throws {
        try await withDocuments { model, first, second in
            var selections: [URL?] = []
            let observer = model.$pendingSelectionURL.combineLatest(model.$selectedURL)
                .map { $0 ?? $1 }.removeDuplicates().sink { selections.append($0) }
            defer { observer.cancel() }
            model.edit("edited first")
            let switching = model.select(second)
            try expect(model.listSelectionURL == second)
            try expect(model.selectedURL == first)
            try expect(model.text == "edited first")
            await switching?.value
            try expect(model.selectedURL == second)
            try expect(model.text == "second")
            try expect(!model.busy && model.pendingSelectionURL == nil)
            try expect(selections == [first, second])
            try expect(String(contentsOf: first, encoding: .utf8) == "edited first")
            try expect(String(contentsOf: second, encoding: .utf8) == "second")
        }
    }

    func testConflictSaveDoesNotBounceThePendingSelection() async throws {
        try await withDocuments { model, first, second in
            var selections: [URL?] = []
            let observer = model.$pendingSelectionURL.combineLatest(model.$selectedURL)
                .map { $0 ?? $1 }.removeDuplicates().sink { selections.append($0) }
            defer { observer.cancel() }
            model.edit("local draft")
            try Data("remote edit".utf8).write(to: first)
            await model.select(second)?.value
            try expect(selections == [first, second])
            try expect(model.selectedURL == second && model.text == "second")
            try expect(String(contentsOf: first, encoding: .utf8) == "remote edit")
            let conflicts = model.files.filter { $0.url != first && $0.url != second }
            try expect(conflicts.count == 1)
            try expect(String(contentsOf: conflicts[0].url, encoding: .utf8) == "local draft")
        }
    }

    func testSaveFailureKeepsThePreviousDocumentAndDraft() async throws {
        try await withDocuments { model, first, second in
            model.edit("unsaved first")
            try FileManager.default.removeItem(at: first)
            let switching = model.select(second)
            try expect(model.listSelectionURL == second)
            await switching?.value
            try expect(model.listSelectionURL == first && model.selectedURL == first)
            try expect(model.text == "unsaved first" && model.dirty)
            try expect(model.recovery[first.path]?.text == "unsaved first")
            try expect(model.error != nil && !model.busy && model.pendingSelectionURL == nil)
            try expect(String(contentsOf: second, encoding: .utf8) == "second")
        }
    }

    func testReadFailureRestoresThePreviousSelection() async throws {
        try await withDocuments { model, first, second in
            try FileManager.default.removeItem(at: second)
            let switching = model.select(second)
            try expect(model.listSelectionURL == second)
            await switching?.value
            try expect(model.listSelectionURL == first && model.selectedURL == first)
            try expect(model.text == "first")
            try expect(model.error != nil && !model.busy && model.pendingSelectionURL == nil)
        }
    }
}
