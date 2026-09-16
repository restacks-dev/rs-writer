import Foundation

struct Heading: Identifiable {
    let offset: Int
    let level: Int
    let title: String
    var id: Int { offset }
}

enum TextAnalysis {
    static func words(_ text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.filter { $0.contains(where: { $0.isLetter || $0.isNumber }) }.count
    }

    static func headings(_ text: String) -> [Heading] {
        let source = text as NSString
        var headings: [Heading] = []
        var fence: String?
        source.enumerateSubstrings(in: NSRange(location: 0, length: source.length), options: .byLines) { line, range, _, _ in
            guard let line else { return }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let marker = String(trimmed.prefix(3))
                if fence == nil { fence = marker } else if fence == marker { fence = nil }
                return
            }
            guard fence == nil else { return }
            let level = line.prefix(while: { $0 == "#" }).count
            guard (1...6).contains(level), line.dropFirst(level).first == " " else { return }
            let title = line.dropFirst(level + 1).trimmingCharacters(in: .whitespaces)
            headings.append(Heading(offset: range.location, level: level, title: title))
        }
        return headings
    }
}
