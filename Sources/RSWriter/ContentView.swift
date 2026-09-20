import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: WriterModel
    @StateObject private var preview = PreviewController()
    @State private var namePrompt: NamePrompt?
    @FocusState private var searchFocused: Bool
    @AppStorage("appearance") private var appearance = "system"

    enum NamingAction: String {
        case document = "Nieuw document", folder = "Nieuwe map", rename = "Naam wijzigen"
    }

    var body: some View {
        VStack(spacing: 0) {
            if let notice = model.notice {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle").foregroundStyle(BrandPalette.accent)
                    Text(notice).font(.callout)
                    Spacer()
                    Button { model.notice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("Melding sluiten")
                }.padding(12).background(BrandPalette.accent.opacity(0.07))
                Divider()
            }
            if model.root == nil { welcome }
            else {
                HSplitView {
                    if model.showLibrary {
                        library.frame(width: 185)
                        documents.frame(width: 245)
                    }
                    writingArea.frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            Divider()
            statusBar
        }
        .frame(minWidth: 850, minHeight: 560)
        .background(Color(nsColor: .textBackgroundColor))
        .tint(BrandPalette.accent)
        .preferredColorScheme(appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
        .toolbar { toolbar }
        .navigationTitle(model.title)
        .alert("Kan actie niet voltooien", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: .writerNew)) { _ in presentNamePrompt(.document) }
        .onReceive(NotificationCenter.default.publisher(for: .writerRename)) { _ in presentNamePrompt(.rename) }
        .onReceive(NotificationCenter.default.publisher(for: .writerExport)) { note in
            if note.object as? String == "html" { preview.exportHTML(model: model) }
            else { preview.printDocument(model: model) }
        }
    }

    private var welcome: some View {
        VStack(spacing: 22) {
            Spacer()
            appIcon.frame(width: 80, height: 80)
            VStack(spacing: 12) {
                Text(model.libraryAccessNeedsRenewal ? "Open je bibliotheek opnieuw." : "Een plek voor je woorden.")
                    .font(.system(size: 32, weight: .medium, design: .serif))
                Text(model.libraryAccessNeedsRenewal
                     ? "RS Writer kan de opgeslagen maptoegang niet herstellen.\nVerbind je drive indien nodig en kies dezelfde map opnieuw. Je documenten blijven bewaard."
                     : "Jouw tekst. Jouw bestanden. Op elke Mac.")
                    .font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Button(action: model.chooseFolder) {
                Label(model.libraryAccessNeedsRenewal ? "Kies je bibliotheekmap opnieuw" : "Kies je bibliotheekmap", systemImage: "folder")
            }
                .buttonStyle(.borderedProminent).tint(BrandPalette.accent).controlSize(.large).padding(.top, 10)
            Text("Een map op iCloud Drive, Dropbox of je gedeelde drive.\nRS Writer bewaart je documenten als gewone Markdown-bestanden.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(5)
            Spacer()
            Text("RS WRITER").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(3).foregroundStyle(.tertiary).padding(.bottom, 32)
        }.frame(maxWidth: .infinity)
    }

    private var appIcon: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BIBLIOTHEEK").font(.system(size: 10, weight: .semibold)).tracking(1.4).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.top, 25).padding(.bottom, 12)
            VStack(spacing: 3) {
                libraryRow("Alle documenten", icon: "tray", selected: model.selectedFolder == nil && !model.onlyFavorites) {
                    model.selectedFolder = nil; model.onlyFavorites = false
                }
                libraryRow("Favorieten", icon: "star", selected: model.onlyFavorites) { model.selectedFolder = nil; model.onlyFavorites = true }
            }.padding(.horizontal, 9)
            HStack {
                Text("MAPPEN").font(.system(size: 10, weight: .semibold)).tracking(1.4)
                Spacer()
                Button { presentNamePrompt(.folder) } label: { Image(systemName: "plus").font(.system(size: 11)) }.buttonStyle(.plain).help("Nieuwe map")
            }.foregroundStyle(.secondary).padding(.horizontal, 18).padding(.top, 32).padding(.bottom, 10)
            ScrollView {
                VStack(spacing: 3) {
                    libraryRow(model.root?.lastPathComponent ?? "Bibliotheek", icon: "folder", selected: model.selectedFolder == "") { model.selectedFolder = ""; model.onlyFavorites = false }
                    ForEach(model.folders, id: \.self) { folder in
                        libraryRow((folder as NSString).lastPathComponent, icon: "folder", selected: model.selectedFolder == folder, indent: min(3, folder.filter { $0 == "/" }.count + 1)) {
                            model.selectedFolder = folder; model.onlyFavorites = false
                        }.help(folder)
                    }
                }.padding(.horizontal, 9)
            }
            Spacer(minLength: 0)
            if !model.recovery.isEmpty {
                Button { Task { await model.recoverDrafts() } } label: { Label("Herstelkopieën bewaren", systemImage: "arrow.counterclockwise") }
                    .font(.caption).buttonStyle(.plain).padding(16).disabled(model.busy)
            }
            Divider().padding(.horizontal, 16)
            Button(action: model.chooseFolder) {
                HStack {
                    Image(systemName: "externaldrive")
                    Text(model.root?.lastPathComponent ?? "Kies map").lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 10))
                }.font(.system(size: 11)).foregroundStyle(.secondary).padding(16)
            }.buttonStyle(.plain).help("Bibliotheekmap wijzigen")
        }.background(Color(nsColor: .windowBackgroundColor))
    }

    private func libraryRow(_ title: String, icon: String, selected: Bool, indent: Int = 0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon).font(.system(size: 13)).frame(width: 17).foregroundStyle(selected ? BrandPalette.accent : .secondary)
                Text(title).font(.system(size: 12)).lineLimit(1)
                Spacer(minLength: 0)
            }.padding(.leading, CGFloat(indent * 9)).padding(.horizontal, 9).padding(.vertical, 8)
                .background(selected ? BrandPalette.accent.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private var documents: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Zoek documenten", text: $model.query).textFieldStyle(.plain).focused($searchFocused)
                if !model.query.isEmpty { Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.secondary) }
            }.font(.system(size: 12)).padding(9).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 6)).padding(14)
            HStack {
                Text(model.onlyFavorites ? "Favorieten" : model.selectedFolder.flatMap { $0.isEmpty ? nil : ($0 as NSString).lastPathComponent } ?? "Alle documenten").fontWeight(.medium)
                Spacer()
                Menu {
                    Button("Laatst gewijzigd") { model.sortByName = false }
                    Button("Naam A–Z") { model.sortByName = true }
                } label: { Image(systemName: "arrow.up.arrow.down") }.menuStyle(.borderlessButton).fixedSize().help("Sorteren")
            }.font(.system(size: 11)).foregroundStyle(.secondary).padding(.horizontal, 18).padding(.bottom, 10)
            Divider()
            if model.visibleFiles.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: model.query.isEmpty ? "doc.badge.plus" : "magnifyingglass").font(.system(size: 25, weight: .light))
                    Text(model.query.isEmpty ? "Ruimte voor iets nieuws." : "Geen documenten gevonden.").font(.callout)
                    if model.query.isEmpty { Button("Nieuw document") { presentNamePrompt(.document) }.buttonStyle(.link) }
                }.foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: Binding(get: { model.listSelectionURL }, set: { if let url = $0 { model.select(url) } })) {
                    ForEach(model.visibleFiles) { file in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 5) {
                                Text(file.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                                Spacer(minLength: 0)
                                if model.favorites.contains(file.relativePath) { Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(BrandPalette.accent) }
                            }
                            HStack(spacing: 6) {
                                Text(file.modified, style: .date)
                                if !file.folder.isEmpty { Text("·"); Text(file.folder).lineLimit(1) }
                            }.font(.system(size: 10)).foregroundStyle(.secondary)
                        }.padding(.vertical, 10).tag(file.url)
                            .contextMenu {
                                Button(model.favorites.contains(file.relativePath) ? "Verwijder uit favorieten" : "Maak favoriet") { model.toggleFavorite(file) }
                                Button("Toon in Finder") { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
                            }
                    }
                }.listStyle(.inset).scrollContentBackground(.hidden).disabled(model.busy)
            }
            Divider()
            HStack {
                Button { presentNamePrompt(.document) } label: { Label("Nieuw document", systemImage: "square.and.pencil") }.buttonStyle(.plain)
                Spacer()
                Text("\(model.visibleFiles.count)").monospacedDigit()
            }.font(.system(size: 11)).foregroundStyle(.secondary).padding(14)
        }.background(Color(nsColor: .textBackgroundColor))
    }

    private var writingArea: some View {
        VStack(spacing: 0) {
            if model.selectedURL != nil {
                HStack(spacing: 8) {
                    Text(model.selectedURL?.lastPathComponent ?? "").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    if model.dirty { Circle().fill(BrandPalette.accent).frame(width: 5, height: 5).accessibilityLabel("Niet opgeslagen") }
                    Spacer()
                    if model.focusMode { Text("FOCUS").font(.system(size: 9, weight: .medium)).tracking(1.4).foregroundStyle(BrandPalette.accent) }
                }.padding(.horizontal, 25).padding(.vertical, 16)
                HSplitView {
                    MarkdownEditor(model: model).frame(minWidth: 280)
                    if model.showPreview {
                        MarkdownPreview(model: model, controller: preview).frame(minWidth: 280)
                    }
                    if model.showOutline {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("INHOUD").font(.system(size: 10, weight: .semibold)).tracking(1.4).foregroundStyle(.secondary)
                            if model.headings.isEmpty { Text("Koppen verschijnen hier.").font(.caption).foregroundStyle(.secondary) }
                            ScrollView {
                                VStack(alignment: .leading, spacing: 14) {
                                    ForEach(model.headings) { heading in
                                        Button { model.jumpOffset = nil; DispatchQueue.main.async { model.jumpOffset = heading.offset } } label: {
                                            Text(heading.title).font(.system(size: 12)).multilineTextAlignment(.leading).padding(.leading, CGFloat((heading.level - 1) * 10))
                                        }.buttonStyle(.plain)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }.padding(18).frame(minWidth: 170, idealWidth: 200, maxWidth: 240, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
            } else {
                VStack(spacing: 13) {
                    appIcon.frame(width: 64, height: 64)
                    Text("Begin met een gedachte.").font(.system(size: 24, design: .serif))
                    Button("Nieuw document  ⌘N") { presentNamePrompt(.document) }.buttonStyle(.link)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle().fill(model.dirty || model.status.contains("niet") ? Color.orange : BrandPalette.accent).frame(width: 5, height: 5)
            Text(model.status).lineLimit(1)
            Spacer()
            if model.selectedURL != nil {
                Text("\(model.wordCount) woorden")
                Text("·").padding(.horizontal, 3)
                Text("\(model.text.count) tekens")
                Text("·").padding(.horizontal, 3)
                Text("\(max(1, Int(ceil(Double(model.wordCount) / 200)))) min lezen")
            }
        }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 18).frame(height: 30)
            .background(Color(nsColor: .windowBackgroundColor))
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(id: "library", placement: .navigation) {
            Button { model.showLibrary.toggle() } label: { Image(systemName: "sidebar.left") }.help("Bibliotheek tonen of verbergen (⌘⇧L)")
        }
        // Give every control its own native toolbar item and tooltip region.
        // Nesting them in one HStack lets the parent's help cover neighboring buttons.
        ToolbarItem(id: "new-document", placement: .primaryAction) {
            Button { presentNamePrompt(.document) } label: { Image(systemName: "square.and.pencil") }
                .help("Nieuw document (⌘N)").accessibilityLabel("Nieuw document").disabled(model.root == nil)
        }
        ToolbarItem(id: "focus", placement: .primaryAction) {
            Button { model.focusMode.toggle() } label: { Image(systemName: "scope").foregroundStyle(model.focusMode ? BrandPalette.accent : .secondary) }
                .help("Focus op de huidige alinea (⌘⇧F)").accessibilityLabel("Focus op de huidige alinea")
        }
        ToolbarItem(id: "outline", placement: .primaryAction) {
            Button { model.showOutline.toggle() } label: { Image(systemName: "list.bullet.indent").foregroundStyle(model.showOutline ? BrandPalette.accent : .secondary) }
                .help("Documentinhoud").accessibilityLabel("Documentinhoud")
        }
        ToolbarItem(id: "preview", placement: .primaryAction) {
            Button { model.showPreview.toggle() } label: { Image(systemName: "rectangle.split.2x1").foregroundStyle(model.showPreview ? BrandPalette.accent : .secondary) }
                .help("Markdown-preview (⌘R)").accessibilityLabel("Markdown-preview")
        }
        ToolbarItem(id: "document-actions", placement: .primaryAction) {
            Menu {
                Button("Bewaar als…", action: model.saveAs)
                Button("Naam wijzigen…") { presentNamePrompt(.rename) }
                Divider()
                Button("Exporteer HTML…") { preview.exportHTML(model: model) }.disabled(model.busy || preview.preparingOutput)
                Button("Print / exporteer PDF…") { preview.printDocument(model: model) }.disabled(model.busy || preview.preparingOutput)
                Divider()
                Button("Toon in Finder") { if let url = model.selectedURL { NSWorkspace.shared.activateFileViewerSelecting([url]) } }
            } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).fixedSize().help("Documentacties").accessibilityLabel("Documentacties").disabled(model.selectedURL == nil)
        }
    }

    private func presentNamePrompt(_ action: NamingAction) {
        guard model.root != nil, !model.busy, namePrompt == nil,
              let window = NSApp.keyWindow, window.attachedSheet == nil else { return }
        let folder = model.selectedFolder.flatMap { $0.isEmpty ? nil : $0 } ?? model.root!.lastPathComponent
        let prompt = NamePrompt(
            title: action.rawValue,
            message: action == .rename ? "Geef ‘\(model.title)’ een nieuwe naam." : "Bewaar in ‘\(folder)’.",
            initialName: action == .rename ? model.title : (action == .folder ? "Nieuwe map" : "Naamloos"),
            fieldLabel: action == .folder ? "Mapnaam" : "Documentnaam",
            confirmTitle: action == .rename ? "Wijzig naam" : "Maak aan"
        )
        namePrompt = prompt
        prompt.begin(on: window) { chosenName in
            namePrompt = nil
            guard let chosenName else { return }
            Task {
                if action == .rename { _ = await model.rename(name: chosenName) }
                else { _ = await model.createDocument(name: chosenName, folder: action == .folder) }
            }
        }
    }
}
