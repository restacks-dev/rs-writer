import AppKit
import SwiftUI

extension Notification.Name {
    static let writerFormat = Notification.Name("writerFormat")
    static let writerFind = Notification.Name("writerFind")
    static let writerNew = Notification.Name("writerNew")
    static let writerRename = Notification.Name("writerRename")
    static let writerExport = Notification.Name("writerExport")
}

struct MarkdownEditor: NSViewRepresentable {
    @ObservedObject var model: WriterModel
    @AppStorage("fontSize") var fontSize = 19.0
    @AppStorage("lineWidth") var lineWidth = 720.0
    @AppStorage("spellCheck") var spellCheck = true

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        let editor = WritingTextView()
        editor.isRichText = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isGrammarCheckingEnabled = false
        editor.allowsUndo = true
        editor.usesFindBar = true
        editor.isIncrementalSearchingEnabled = true
        editor.isHorizontallyResizable = false
        editor.isVerticallyResizable = true
        editor.autoresizingMask = [.width]
        editor.minSize = NSSize(width: 0, height: 0)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainer?.widthTracksTextView = false
        editor.textContainer?.heightTracksTextView = false
        editor.delegate = context.coordinator
        editor.string = model.text
        editor.setAccessibilityLabel("Markdown-editor")
        scroll.documentView = editor
        context.coordinator.editor = editor
        context.coordinator.installObservers()
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let editor = coordinator.editor else { return }
        coordinator.updating = true
        let documentChanged = coordinator.document != model.selectedURL
        if editor.string != model.text || documentChanged {
            let selection = editor.selectedRange()
            editor.string = model.text
            editor.undoManager?.removeAllActions()
            if documentChanged {
                coordinator.document = model.selectedURL
                editor.setSelectedRange(NSRange(location: 0, length: 0))
                editor.scrollToBeginningOfDocument(nil)
            } else {
                editor.setSelectedRange(NSRange(location: min(selection.location, (editor.string as NSString).length), length: 0))
            }
        }
        editor.isEditable = !model.busy
        editor.isContinuousSpellCheckingEnabled = spellCheck
        editor.preferredWidth = lineWidth
        editor.typewriter = model.typewriterMode
        editor.textContainerInset = NSSize(width: 40, height: model.typewriterMode ? 180 : 52)
        editor.relayout()
        editor.insertionPointColor = .systemTeal
        editor.backgroundColor = .textBackgroundColor
        scroll.backgroundColor = .textBackgroundColor
        coordinator.style()
        if let offset = model.jumpOffset, coordinator.lastJump != offset {
            coordinator.lastJump = offset
            let range = NSRange(location: min(offset, (editor.string as NSString).length), length: 0)
            editor.setSelectedRange(range)
            editor.scrollRangeToVisible(range)
            editor.window?.makeFirstResponder(editor)
        } else if model.jumpOffset == nil { coordinator.lastJump = nil }
        coordinator.updating = false
        if documentChanged {
            DispatchQueue.main.async { [weak editor] in
                guard let editor else { return }
                editor.window?.makeFirstResponder(editor)
            }
        }
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
        weak var editor: WritingTextView?
        var updating = false
        var document: URL?
        var lastJump: Int?
        var observers: [NSObjectProtocol] = []

        init(_ parent: MarkdownEditor) { self.parent = parent }
        deinit { observers.forEach(NotificationCenter.default.removeObserver) }

        func installObservers() {
            observers.append(NotificationCenter.default.addObserver(forName: .writerFormat, object: nil, queue: .main) { [weak self] note in
                guard let kind = note.object as? String else { return }
                MainActor.assumeIsolated { self?.format(kind) }
            })
            observers.append(NotificationCenter.default.addObserver(forName: .writerFind, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let editor = self?.editor else { return }
                    editor.window?.makeFirstResponder(editor)
                    let item = NSMenuItem()
                    item.tag = NSTextFinder.Action.showFindInterface.rawValue
                    editor.performFindPanelAction(item)
                }
            })
        }

        func textDidChange(_ notification: Notification) {
            guard !updating, let editor else { return }
            parent.model.edit(editor.string)
            style()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !updating, let editor else { return }
            if parent.model.focusMode { style() }
            if parent.model.typewriterMode { editor.centerCaret() }
        }

        func style() {
            guard let editor, let storage = editor.textStorage else { return }
            let full = NSRange(location: 0, length: storage.length)
            let font = NSFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .regular)
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = parent.fontSize * 0.48
            paragraph.paragraphSpacing = 3
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.textColor, .paragraphStyle: paragraph]
            storage.beginEditing()
            storage.setAttributes(attrs, range: full)
            let source = editor.string
            apply("(?m)^#{1,6} .+$", source: source, storage: storage, attributes: [.font: NSFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .bold)])
            apply("(?m)^(#{1,6} |[ \\t]*[-*+] |[ \\t]*[0-9]+\\. |[ \\t]*> ?)", source: source, storage: storage, attributes: [.foregroundColor: NSColor.tertiaryLabelColor])
            apply("\\*\\*[^*\\n]+\\*\\*|__[^_\\n]+__", source: source, storage: storage, attributes: [.font: NSFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .bold)])
            apply("`[^`\\n]+`", source: source, storage: storage, attributes: [.foregroundColor: NSColor.systemTeal])
            apply("\\[[^\\]\\n]+\\]\\([^\\)\\n]+\\)", source: source, storage: storage, attributes: [.foregroundColor: NSColor.systemTeal])
            if parent.model.focusMode, storage.length > 0 {
                let location = min(editor.selectedRange().location, max(0, storage.length - 1))
                let active = (source as NSString).paragraphRange(for: NSRange(location: location, length: 0))
                if active.location > 0 {
                    storage.addAttribute(.foregroundColor, value: NSColor.textColor.withAlphaComponent(0.22), range: NSRange(location: 0, length: active.location))
                }
                if NSMaxRange(active) < storage.length {
                    storage.addAttribute(.foregroundColor, value: NSColor.textColor.withAlphaComponent(0.22), range: NSRange(location: NSMaxRange(active), length: storage.length - NSMaxRange(active)))
                }
            }
            storage.endEditing()
            editor.typingAttributes = attrs
        }

        private func apply(_ pattern: String, source: String, storage: NSTextStorage, attributes: [NSAttributedString.Key: Any]) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            for match in regex.matches(in: source, range: NSRange(location: 0, length: storage.length)) {
                storage.addAttributes(attributes, range: match.range)
            }
        }

        func format(_ kind: String) {
            guard let editor, editor.isEditable else { return }
            let selected = editor.selectedRange()
            let value = (editor.string as NSString).substring(with: selected)
            let pair: (String, String)
            switch kind {
            case "bold": pair = ("**", "**")
            case "italic": pair = ("*", "*")
            case "code": pair = ("`", "`")
            case "link": pair = ("[", "](https://)")
            case "heading": pair = ("## ", "")
            case "list": pair = ("- ", "")
            case "task": pair = ("- [ ] ", "")
            case "quote": pair = ("> ", "")
            default: return
            }
            editor.insertText(pair.0 + value + pair.1, replacementRange: selected)
            editor.setSelectedRange(NSRange(location: selected.location + (pair.0 as NSString).length, length: selected.length))
            editor.window?.makeFirstResponder(editor)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)), textView.selectedRange().length == 0 else { return false }
            let source = textView.string as NSString
            let cursor = textView.selectedRange().location
            let lineRange = source.lineRange(for: NSRange(location: cursor, length: 0))
            let line = source.substring(with: NSRange(location: lineRange.location, length: cursor - lineRange.location))
            guard let regex = try? NSRegularExpression(pattern: "^(\\s*)([-*+] |[0-9]+\\. |>[ ]?)(\\[[ xX]\\] )?"),
                  let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) else { return false }
            let prefix = (line as NSString).substring(with: match.range)
            if line.trimmingCharacters(in: .whitespaces) == prefix.trimmingCharacters(in: .whitespaces) {
                textView.insertText("", replacementRange: NSRange(location: lineRange.location, length: cursor - lineRange.location))
            } else {
                var next = prefix.replacingOccurrences(of: "[x]", with: "[ ]").replacingOccurrences(of: "[X]", with: "[ ]")
                let marker = (line as NSString).substring(with: match.range(at: 2))
                if let number = Int(marker.trimmingCharacters(in: CharacterSet(charactersIn: ". "))) {
                    next = next.replacingOccurrences(of: marker, with: "\(number + 1). ")
                }
                textView.insertText("\n" + next, replacementRange: textView.selectedRange())
            }
            return true
        }
    }
}

final class WritingTextView: NSTextView {
    var preferredWidth = 720.0
    var typewriter = false

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        relayout()
    }

    func relayout() {
        let available = enclosingScrollView?.contentSize.width ?? bounds.width
        let horizontalPadding: CGFloat = available < 420 ? 48 : 80
        let width = max(160, min(preferredWidth, available - horizontalPadding))
        textContainer?.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        let inset = max(24, (available - width) / 2)
        if textContainerInset.width != inset { textContainerInset.width = inset }
    }

    func centerCaret() {
        guard let scroll = enclosingScrollView, let manager = layoutManager, let container = textContainer else { return }
        let range = NSRange(location: min(selectedRange().location, (string as NSString).length), length: 0)
        let glyph = manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let rect = manager.boundingRect(forGlyphRange: glyph, in: container)
        let y = max(0, rect.midY + textContainerOrigin.y - scroll.contentSize.height * 0.45)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: y))
        scroll.reflectScrolledClipView(scroll.contentView)
    }
}
