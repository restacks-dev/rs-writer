import Foundation

struct LibraryFile: Identifiable, Hashable, Sendable {
    var id: URL { url }
    let url: URL
    let relativePath: String
    let modified: Date
    var title: String { url.deletingPathExtension().lastPathComponent }
    var folder: String { (relativePath as NSString).deletingLastPathComponent }
}

struct LibrarySnapshot: Sendable {
    let files: [LibraryFile]
    let folders: [String]
}

struct SaveResult: Sendable {
    let url: URL
    let data: Data
    let conflict: Bool
}

enum LibraryError: LocalizedError {
    case unavailable, invalidName, invalidEncoding, missing, tooLarge
    var errorDescription: String? {
        switch self {
        case .unavailable: return "De bibliotheekmap is niet bereikbaar. Verbind de drive opnieuw. Je tekst blijft lokaal bewaard."
        case .invalidName: return "Gebruik een naam zonder /, : of verborgen beginpunt."
        case .invalidEncoding: return "Dit bestand is geen geldige UTF-8-tekst. Het is niet gewijzigd."
        case .missing: return "Het bestand is verplaatst of verwijderd. Je tekst blijft lokaal bewaard. Gebruik ‘Bewaar als’ om verder te gaan."
        case .tooLarge: return "Dit bestand is groter dan 10 MB. Open het in een editor voor grote bestanden."
        }
    }
}

/// Serializes this app's disk access. NSFileCoordinator also cooperates with
/// local file presenters and cloud providers; cross-machine sync stays with the provider.
actor LibraryDisk {
    static let extensions: Set<String> = ["md", "markdown", "mdown", "txt"]

    func scan(_ root: URL) throws -> LibrarySnapshot {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw LibraryError.unavailable
        }
        var scanError: Error?
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, error in scanError = error; return false }
        ) else { throw LibraryError.unavailable }
        var files: [LibraryFile] = [], folders: [String] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey])
            if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
            let path = url.standardizedFileURL.resolvingSymlinksInPath().pathComponents
                .dropFirst(root.standardizedFileURL.resolvingSymlinksInPath().pathComponents.count).joined(separator: "/")
            if values.isDirectory == true { folders.append(path) }
            else if Self.extensions.contains(url.pathExtension.lowercased()) {
                files.append(LibraryFile(url: url, relativePath: path, modified: values.contentModificationDate ?? .distantPast))
            }
        }
        if let scanError { throw scanError }
        return LibrarySnapshot(files: files, folders: folders.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    func read(_ url: URL) throws -> Data {
        try coordinatedRead(url) { resolved in
            let values = try resolved.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) <= 10_000_000 else { throw LibraryError.tooLarge }
            let data = try Data(contentsOf: resolved)
            guard String(data: data, encoding: .utf8) != nil else { throw LibraryError.invalidEncoding }
            return data
        }
    }

    func save(_ text: String, to url: URL, expected: Data) throws -> SaveResult {
        let data = Data(text.utf8)
        return try coordinatedWrite(url) { resolved in
            guard FileManager.default.fileExists(atPath: resolved.path) else { throw LibraryError.missing }
            let current = try Data(contentsOf: resolved)
            if current != expected && current != data {
                // Never overwrite another computer's edits. UUID also avoids concurrent copy-name collisions.
                let copy = resolved.deletingLastPathComponent().appendingPathComponent(
                    "\(resolved.deletingPathExtension().lastPathComponent) (conflict \(Self.timestamp()) \(UUID().uuidString.prefix(6))).\(resolved.pathExtension)"
                )
                try data.write(to: copy, options: .withoutOverwriting)
                return SaveResult(url: copy, data: data, conflict: true)
            }
            if current != data { try data.write(to: resolved, options: .atomic) }
            return SaveResult(url: url, data: data, conflict: false)
        }
    }

    func create(in directory: URL, name: String, text: String = "") throws -> URL {
        let clean = try Self.validName(name)
        let filename = Self.extensions.contains((clean as NSString).pathExtension.lowercased()) ? clean : clean + ".md"
        let url = directory.appendingPathComponent(filename)
        return try coordinatedWrite(url) { resolved in
            try Data(text.utf8).write(to: resolved, options: .withoutOverwriting)
            return url
        }
    }

    func createFolder(in directory: URL, name: String) throws {
        let url = directory.appendingPathComponent(try Self.validName(name), isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    }

    func rename(_ url: URL, name: String) throws -> URL {
        let clean = try Self.validName(name)
        let filename = Self.extensions.contains((clean as NSString).pathExtension.lowercased()) ? clean : clean + "." + url.pathExtension
        let destination = url.deletingLastPathComponent().appendingPathComponent(filename)
        if destination == url { return url }
        var coordinationError: NSError?
        var result: Result<URL, Error>?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: url, options: .forMoving, writingItemAt: destination, options: [], error: &coordinationError) { source, target in
            result = Result {
                try FileManager.default.moveItem(at: source, to: target)
                coordinator.item(at: source, didMoveTo: target)
                return destination
            }
        }
        if let coordinationError { throw coordinationError }
        return try result?.get() ?? { throw LibraryError.unavailable }()
    }

    static func validName(_ value: String) throws -> String {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.hasPrefix("."), !name.contains("/"), !name.contains(":"),
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw LibraryError.invalidName
        }
        return name
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HHmmss"
        return formatter.string(from: Date())
    }

    private func coordinatedRead<T>(_ url: URL, body: (URL) throws -> T) throws -> T {
        var error: NSError?
        var result: Result<T, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { resolved in result = Result { try body(resolved) } }
        if let error { throw error }
        guard let result else { throw LibraryError.unavailable }
        return try result.get()
    }

    private func coordinatedWrite<T>(_ url: URL, body: (URL) throws -> T) throws -> T {
        var error: NSError?
        var result: Result<T, Error>?
        NSFileCoordinator().coordinate(writingItemAt: url, options: [], error: &error) { resolved in result = Result { try body(resolved) } }
        if let error { throw error }
        guard let result else { throw LibraryError.unavailable }
        return try result.get()
    }
}
