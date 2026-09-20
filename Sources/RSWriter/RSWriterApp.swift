import SwiftUI

@main
struct RSWriterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = WriterModel()

    var body: some Scene {
        Window("RS Writer", id: "writer") {
            ContentView().environmentObject(model).onAppear { delegate.model = model }
        }
        .defaultSize(width: 1200, height: 790)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nieuw document") { NotificationCenter.default.post(name: .writerNew, object: nil) }.keyboardShortcut("n").disabled(model.root == nil || model.busy)
                Button("Kies bibliotheekmap…", action: model.chooseFolder).keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {
                Button("Bewaar") { Task { await model.save() } }.keyboardShortcut("s").disabled(model.selectedURL == nil)
                Button("Bewaar als…", action: model.saveAs).keyboardShortcut("s", modifiers: [.command, .shift]).disabled(model.selectedURL == nil)
                Button("Naam wijzigen…") { NotificationCenter.default.post(name: .writerRename, object: nil) }.disabled(model.selectedURL == nil)
                Divider()
                Button("Exporteer HTML…") { NotificationCenter.default.post(name: .writerExport, object: "html") }.disabled(model.selectedURL == nil || model.busy)
                Button("Print / exporteer PDF…") { NotificationCenter.default.post(name: .writerExport, object: "pdf") }.keyboardShortcut("p").disabled(model.selectedURL == nil || model.busy)
            }
            CommandGroup(after: .textEditing) {
                Button("Zoek in document…") { NotificationCenter.default.post(name: .writerFind, object: nil) }.keyboardShortcut("f").disabled(model.selectedURL == nil)
            }
            CommandMenu("Markdown") {
                format("Vet", "bold", key: "b")
                format("Cursief", "italic", key: "i")
                format("Link", "link", key: "k")
                Divider()
                format("Kop", "heading")
                format("Lijst", "list")
                format("Taak", "task")
                format("Citaat", "quote")
                format("Code", "code")
            }
            CommandGroup(after: .sidebar) {
                Toggle("Bibliotheek", isOn: $model.showLibrary).keyboardShortcut("l", modifiers: [.command, .shift])
                Toggle("Markdown-preview", isOn: $model.showPreview).keyboardShortcut("r")
                Toggle("Documentinhoud", isOn: $model.showOutline).keyboardShortcut("o", modifiers: [.command, .shift])
                Divider()
                Toggle("Focus op alinea", isOn: $model.focusMode).keyboardShortcut("f", modifiers: [.command, .shift])
                Toggle("Typemachinemodus", isOn: $model.typewriterMode).keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }
        Settings { WriterSettings().environmentObject(model).tint(BrandPalette.accent) }
    }

    @ViewBuilder private func format(_ label: String, _ action: String, key: KeyEquivalent? = nil) -> some View {
        if let key {
            Button(label) { NotificationCenter.default.post(name: .writerFormat, object: action) }.keyboardShortcut(key).disabled(model.selectedURL == nil)
        } else {
            Button(label) { NotificationCenter.default.post(name: .writerFormat, object: action) }.disabled(model.selectedURL == nil)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: WriterModel?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model, model.dirty else { return .terminateNow }
        Task {
            let saved = await model.save()
            if saved { sender.reply(toApplicationShouldTerminate: true) }
            else {
                let alert = NSAlert()
                alert.messageText = "Je tekst is nog niet op de drive opgeslagen"
                alert.informativeText = "RS Writer bewaart een lokale herstelkopie. Je kunt stoppen en deze tekst bij de volgende start herstellen, of verder werken."
                alert.addButton(withTitle: "Verder werken")
                alert.addButton(withTitle: "Stop met herstelkopie")
                sender.reply(toApplicationShouldTerminate: alert.runModal() == .alertSecondButtonReturn)
            }
        }
        return .terminateLater
    }
}

struct WriterSettings: View {
    @EnvironmentObject var model: WriterModel
    @AppStorage("fontSize") private var fontSize = 19.0
    @AppStorage("lineWidth") private var lineWidth = 720.0
    @AppStorage("spellCheck") private var spellCheck = true
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        Form {
            Section("Bibliotheek") {
                LabeledContent("Map") { Text(model.root?.path ?? "Nog geen map gekozen").lineLimit(2).textSelection(.enabled).font(.caption) }
                Button("Kies een andere map…", action: model.chooseFolder)
                Text("Kies op elke Mac dezelfde gedeelde map. Je cloudprovider of netwerkdrive verzorgt de synchronisatie.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Schrijven") {
                LabeledContent("Lettergrootte", value: "\(Int(fontSize)) pt")
                Slider(value: $fontSize, in: 14...28, step: 1)
                Picker("Tekstbreedte", selection: $lineWidth) {
                    Text("Smal").tag(560.0)
                    Text("Normaal").tag(720.0)
                    Text("Breed").tag(900.0)
                }
                Toggle("Spelling controleren", isOn: $spellCheck)
            }
            Section("Weergave") {
                Picker("Thema", selection: $appearance) {
                    Text("Volg systeem").tag("system")
                    Text("Licht").tag("light")
                    Text("Donker").tag("dark")
                }
            }
            Section {
                Text("RS Writer 0.1 · Markdown, in jouw eigen map.").font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).frame(width: 470, height: 520)
    }
}
