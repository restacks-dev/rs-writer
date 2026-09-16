import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class WriterModel: ObservableObject {
    @Published var root: URL?
    @Published var files: [LibraryFile] = []
    @Published var folders: [String] = []
    @Published var selectedURL: URL?
    @Published var text = ""
    @Published var query = ""
    @Published var selectedFolder: String? = nil
    @Published var onlyFavorites = false
    @Published var sortByName = false
    @Published var dirty = false
    @Published var busy = false
    @Published var status = "Kies je schrijfplek"
    @Published var notice: String?
    @Published var error: String?
    @Published var showPreview = false
    @Published var showOutline = false
    @Published var focusMode = false
    @Published var typewriterMode = false
    @Published var showLibrary = true
    @Published var jumpOffset: Int?
    @Published var recovery: [String: RecoveryDraft] = [:]
    @Published var favorites: Set<String> = []
    let disk = LibraryDisk()
    private var baseline = Data()
    private var debounce: Task<Void, Never>?
    private var monitor: Task<Void, Never>?
    private var saveInFlight: Task<Bool, Never>?
    private var scopedURL: URL?
    private var refreshing = false
    private var lastSaveError: String?

    var visibleFiles: [LibraryFile] {
        files.filter { file in
            (selectedFolder == nil || file.folder == selectedFolder || file.folder.hasPrefix(selectedFolder! + "/")) &&
            (!onlyFavorites || favorites.contains(file.relativePath)) &&
            (query.isEmpty || file.relativePath.localizedCaseInsensitiveContains(query))
        }.sorted {
            if sortByName { return $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
            if $0.modified == $1.modified { return $0.relativePath < $1.relativePath }
            return $0.modified > $1.modified
        }
    }

    var title: String { selectedURL?.deletingPathExtension().lastPathComponent ?? "RS Writer" }
    var wordCount: Int { TextAnalysis.words(text) }
    var headings: [Heading] { TextAnalysis.headings(text) }

    init() {
        if let data = UserDefaults.standard.data(forKey: "recoveryV2") {
            recovery = (try? JSONDecoder().decode([String: RecoveryDraft].self, from: data)) ?? [:]
        }
        Task { await restore() }
        monitor = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Kies je Markdown-bibliotheek"
        panel.message = "Kies een lokale map, cloudmap of verbonden gedeelde drive. Je bestanden blijven gewone Markdown-bestanden."
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Gebruik map"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await useFolder(url) }
    }

    private func restore() async {
        #if DEBUG
        // Only a separately identified Debug test bundle supplies this key.
        if let path = Bundle.main.object(forInfoDictionaryKey: "RSWriterDemoLibrary") as? String {
            await useFolder(URL(fileURLWithPath: path), persist: false)
            return
        }
        #endif
        guard let data = UserDefaults.standard.data(forKey: "libraryBookmark") else { return }
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &stale)
            await useFolder(url, persist: true)
        } catch { self.error = "De opgeslagen map kon niet worden geopend. Kies de bibliotheekmap opnieuw.\n\(error.localizedDescription)" }
    }

    func useFolder(_ url: URL, persist: Bool = true) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        guard await save() else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        do {
            let snapshot = try await disk.scan(url)
            let bookmark = persist ? try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) : nil
            scopedURL?.stopAccessingSecurityScopedResource()
            scopedURL = accessed ? url : nil
            root = url
            files = snapshot.files
            folders = snapshot.folders
            selectedURL = nil
            text = ""
            baseline = Data()
            dirty = false
            selectedFolder = nil
            query = ""
            favorites = Set(UserDefaults.standard.stringArray(forKey: "favorites:\(url.path)") ?? [])
            if let bookmark { UserDefaults.standard.set(bookmark, forKey: "libraryBookmark") }
            status = "\(files.count) documenten"
            if let path = UserDefaults.standard.string(forKey: "lastFile:\(url.path)"),
               let file = files.first(where: { $0.relativePath == path }) {
                await load(file.url)
            } else if let first = visibleFiles.first { await load(first.url) }
        } catch {
            if accessed { url.stopAccessingSecurityScopedResource() }
            self.error = error.localizedDescription
        }
    }

    func select(_ url: URL) {
        guard !busy, url != selectedURL else { return }
        busy = true
        Task {
            defer { busy = false }
            guard await save() else { return }
            await load(url)
        }
    }

    private func load(_ url: URL) async {
        do {
            let data = try await disk.read(url)
            selectedURL = url
            text = String(decoding: data, as: UTF8.self)
            baseline = data
            dirty = false
            jumpOffset = nil
            if let draft = recovery[url.path], draft.text != text {
                text = draft.text
                baseline = draft.baseline
                dirty = true
                notice = "Je niet-opgeslagen tekst is hersteld. Bij een wijziging op de drive bewaart RS Writer jouw tekst als conflictbestand."
            } else { clearRecovery(url) }
            status = dirty ? "Herstelde tekst · nog niet opgeslagen" : "Opgeslagen"
            if let root, let file = files.first(where: { $0.url == url }) {
                UserDefaults.standard.set(file.relativePath, forKey: "lastFile:\(root.path)")
            }
        } catch { self.error = error.localizedDescription }
    }

    func edit(_ value: String) {
        guard selectedURL != nil else { return }
        text = value
        dirty = Data(value.utf8) != baseline
        status = dirty ? "Opslaan…" : "Opgeslagen"
        if let selectedURL {
            if dirty { recovery[selectedURL.path] = RecoveryDraft(text: value, baseline: baseline); persistRecovery() }
            else { clearRecovery(selectedURL) }
        }
        debounce?.cancel()
        debounce = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
            _ = await self?.save(reportFailure: false)
        }
    }

    @discardableResult
    func save(reportFailure: Bool = true) async -> Bool {
        if let existing = saveInFlight {
            guard await existing.value else {
                if reportFailure { error = lastSaveError }
                return false
            }
            if dirty { return await save(reportFailure: reportFailure) }
            return true
        }
        guard dirty, let url = selectedURL else { return true }
        let snapshot = text, expected = baseline
        let task = Task { @MainActor in
            defer { self.saveInFlight = nil }
            do {
                let result = try await disk.save(snapshot, to: url, expected: expected)
                self.baseline = result.data
                self.selectedURL = result.url
                self.clearRecovery(url)
                self.dirty = self.text != snapshot
                if self.dirty {
                    self.recovery[result.url.path] = RecoveryDraft(text: self.text, baseline: result.data)
                    self.persistRecovery()
                }
                self.status = self.dirty ? "Opslaan…" : "Opgeslagen"
                self.lastSaveError = nil
                if result.conflict {
                    self.notice = "Dit bestand is ook op de drive gewijzigd. Jouw tekst staat in ‘\(result.url.lastPathComponent)’. De andere versie is behouden."
                    await self.refresh(checkDocument: false)
                }
                return true
            } catch {
                self.status = "Niet opgeslagen · lokaal herstel beschikbaar"
                self.lastSaveError = error.localizedDescription
                if reportFailure { self.error = error.localizedDescription }
                return false
            }
        }
        saveInFlight = task
        let result = await task.value
        return result
    }

    func refresh(checkDocument: Bool = true) async {
        guard let root, !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        do {
            let snapshot = try await disk.scan(root)
            guard self.root == root else { return }
            files = snapshot.files
            folders = snapshot.folders
            guard checkDocument, !busy, saveInFlight == nil, !dirty, let url = selectedURL else { return }
            let original = baseline
            let data = try await disk.read(url)
            // The user may have typed or switched documents while disk I/O was in flight.
            guard selectedURL == url, !dirty, !busy, saveInFlight == nil, baseline == original else { return }
            if data != baseline {
                text = String(decoding: data, as: UTF8.self)
                baseline = data
                status = "Bijgewerkt vanaf de drive"
            } else if status.hasPrefix("Drive niet bereikbaar") { status = "Opgeslagen" }
        } catch {
            status = "Drive niet bereikbaar of bestand ontbreekt"
        }
    }

    func createDocument(name: String, folder: Bool = false) async -> Bool {
        guard let root, !busy else { return false }
        busy = true
        defer { busy = false }
        guard await save() else { return false }
        let directory = selectedFolder.map { root.appendingPathComponent($0, isDirectory: true) } ?? root
        do {
            if folder { try await disk.createFolder(in: directory, name: name) }
            else {
                let url = try await disk.create(in: directory, name: name)
                query = ""
                onlyFavorites = false
                await load(url)
            }
            await refresh(checkDocument: false)
            return true
        } catch { self.error = error.localizedDescription; return false }
    }

    func rename(name: String) async -> Bool {
        guard !busy else { return false }
        busy = true
        defer { busy = false }
        guard await save(), let url = selectedURL else { return false }
        do {
            let newURL = try await disk.rename(url, name: name)
            selectedURL = newURL
            await refresh(checkDocument: false)
            return true
        } catch { self.error = error.localizedDescription; return false }
    }

    func saveAs() {
        guard selectedURL != nil, !busy else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = selectedURL?.lastPathComponent ?? "Naamloos.md"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        busy = true
        debounce?.cancel()
        Task {
            defer { busy = false }
            // Finish an outstanding autosave before changing the active document.
            if let pending = saveInFlight { _ = await pending.value }
            // NSSavePanel itself handles explicit replacement confirmation.
            do {
                let data = Data(text.utf8)
                try data.write(to: destination, options: .atomic)
                if let original = selectedURL { clearRecovery(original) }
                selectedURL = destination
                baseline = data
                dirty = false
                status = "Opgeslagen"
                notice = "Je werkt nu in ‘\(destination.lastPathComponent)’."
                await refresh(checkDocument: false)
            } catch { self.error = error.localizedDescription }
        }
    }

    func recoverDrafts() async {
        guard let root, !busy else { return }
        busy = true
        defer { busy = false }
        if let pending = saveInFlight { _ = await pending.value }
        var recovered = 0
        for (path, draft) in recovery {
            do {
                _ = try await disk.create(in: root, name: "\(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent) (hersteld \(UUID().uuidString.prefix(6)))", text: draft.text)
                recovery.removeValue(forKey: path)
                persistRecovery()
                recovered += 1
            } catch { self.error = error.localizedDescription; break }
        }
        await refresh(checkDocument: false)
        if recovered > 0 { notice = "\(recovered) herstelkopieën zijn als aparte Markdown-bestanden in je bibliotheek bewaard." }
    }

    func toggleFavorite(_ file: LibraryFile) {
        if favorites.contains(file.relativePath) { favorites.remove(file.relativePath) }
        else { favorites.insert(file.relativePath) }
        if let root { UserDefaults.standard.set(Array(favorites), forKey: "favorites:\(root.path)") }
    }

    private func clearRecovery(_ url: URL) {
        recovery.removeValue(forKey: url.path)
        persistRecovery()
    }

    private func persistRecovery() {
        if let data = try? JSONEncoder().encode(recovery) { UserDefaults.standard.set(data, forKey: "recoveryV2") }
    }
}
