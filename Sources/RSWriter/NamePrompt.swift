import AppKit

/// A standard macOS sheet; AppKit owns layout, appearance and keyboard behavior.
@MainActor
final class NamePrompt: NSObject, NSTextFieldDelegate {
    private let alert = NSAlert()
    private let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))

    init(title: String, message: String, initialName: String, fieldLabel: String, confirmTitle: String) {
        super.init()
        alert.alertStyle = .informational
        alert.icon = NSApplication.shared.applicationIconImage
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirmTitle).keyEquivalent = "\r"
        alert.addButton(withTitle: "Annuleer").keyEquivalent = "\u{1b}"
        field.stringValue = initialName
        field.placeholderString = fieldLabel
        field.setAccessibilityLabel(fieldLabel)
        field.delegate = self
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        updateConfirmation()
    }

    func begin(on window: NSWindow, completion: @escaping (String?) -> Void) {
        alert.beginSheetModal(for: window) { [self] response in
            completion(response == .alertFirstButtonReturn ? field.stringValue : nil)
        }
        field.selectText(nil)
    }

    func controlTextDidChange(_ notification: Notification) { updateConfirmation() }

    private func updateConfirmation() {
        alert.buttons.first?.isEnabled = (try? LibraryDisk.validName(field.stringValue)) != nil
    }
}
