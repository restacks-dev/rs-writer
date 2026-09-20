import SwiftUI
import WebKit
import UniformTypeIdentifiers

@MainActor
final class PreviewController: NSObject, ObservableObject, WKNavigationDelegate {
    let webView: WKWebView
    @Published private(set) var preparingOutput = false
    private let assets = LibraryAssets()
    private var ready = false
    private var latestText = ""
    private var latestURL: URL?
    private var loadedBase: URL?
    private var loadFailure: Error?
    private var outputWindow: NSWindow?
    private var printCompletion: CheckedContinuation<Bool, Never>?
    private weak var model: WriterModel?
    private static let css = """
    :root{color-scheme:light dark;--ink:#262723;--paper:#fff;--muted:#777b77;--line:#e5e7e3;--accent:\(BrandPalette.lightAccentHex);--selection:\(BrandPalette.lightSelectionHex)}
    @media(prefers-color-scheme:dark){:root{--ink:#dadcd7;--paper:#1e201f;--muted:#959b95;--line:#3b403c;--accent:\(BrandPalette.darkAccentHex);--selection:\(BrandPalette.darkSelectionHex)}}
    *{box-sizing:border-box}html{background:var(--paper);color:var(--ink)}body{max-width:780px;margin:0 auto;padding:48px 44px 100px;font:19px/1.75 Charter,Georgia,serif;overflow-wrap:break-word}
    h1,h2,h3,h4,h5,h6{font-family:-apple-system,BlinkMacSystemFont,sans-serif;line-height:1.3;letter-spacing:-.025em;margin:1.5em 0 .6em}h1{font-size:2em;margin-top:0}h2{font-size:1.5em}h3{font-size:1.2em}p{margin:0 0 1.1em}a{color:var(--accent);text-underline-offset:3px}blockquote{margin:1.4em 0;padding:0 0 0 1.2em;border-left:3px solid var(--accent);color:var(--muted)}pre,code{font: .83em/1.65 ui-monospace,Menlo,monospace}code{padding:.15em .35em;background:color-mix(in srgb,var(--ink) 5%,transparent);border-radius:3px}pre{padding:20px;overflow:auto;border:1px solid var(--line);border-radius:6px}pre code{padding:0;background:none;font-size:1em}hr{border:0;border-top:1px solid var(--line);margin:2em 0}img{max-width:100%;height:auto}table{width:100%;border-collapse:collapse;font: .85em/1.5 -apple-system,sans-serif;margin:1.5em 0}th,td{text-align:left;border-bottom:1px solid var(--line);padding:10px}th{font-weight:600}li{margin:.25em 0}input{accent-color:var(--accent)}.empty{color:var(--muted);font-style:italic}
    ::selection{background:var(--selection);color:var(--ink)}
    @media print{:root{--ink:#222;--paper:#fff;--muted:#666;--line:#ddd;--accent:#333}body{max-width:none;padding:0;font-size:12pt}pre,blockquote,table,img{break-inside:avoid}h1,h2,h3{break-after:avoid}a{color:inherit}}
    @media screen and (max-width:420px){body{padding:48px 24px 80px;font-size:17px}h1{font-size:1.7em}}
    """

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.setURLSchemeHandler(assets, forURLScheme: "writer-asset")
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
    }

    func update(model: WriterModel) {
        self.model = model
        latestText = model.text
        latestURL = model.selectedURL
        assets.root = model.root
        let base = model.selectedURL?.deletingLastPathComponent()
        if loadedBase != base || webView.url == nil {
            loadedBase = base
            ready = false
            loadShell()
        } else { render() }
    }

    private func loadShell() {
        loadFailure = nil
        let marked = Self.resource("marked", "js")
        let purify = Self.resource("purify", "js")
        let nonce = UUID().uuidString
        let relativeDirectory: String
        if let root = assets.root, let base = loadedBase {
            relativeDirectory = String(base.path.dropFirst(root.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        } else { relativeDirectory = "" }
        let encoded = relativeDirectory.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let baseURL = "writer-asset:///" + (encoded.isEmpty ? "" : encoded + "/")
        let shell = """
        <!doctype html><html lang="nl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src writer-asset: data:; style-src 'unsafe-inline'; script-src 'nonce-\(nonce)'; base-uri writer-asset:">
        <base href="\(baseURL)"><style>\(Self.css)</style>
        <script nonce="\(nonce)">\(marked)</script><script nonce="\(nonce)">\(purify)</script>
        </head><body><main id="content"></main></body></html>
        """
        webView.loadHTMLString(shell, baseURL: URL(string: baseURL))
    }

    private static func resource(_ name: String, _ ext: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext), let source = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return source
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { ready = true; render() }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        reportLoadFailure(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        reportLoadFailure(error)
    }

    private func reportLoadFailure(_ error: Error) {
        let failure = error as NSError
        // A newer document can replace an in-flight shell load normally.
        guard !(failure.domain == NSURLErrorDomain && failure.code == NSURLErrorCancelled) else { return }
        ready = false
        loadFailure = error
        model?.error = "De Markdown-preview kon niet worden geladen: \(error.localizedDescription)"
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        ready = false
        loadFailure = NSError(domain: "RSWriter.Preview", code: 1, userInfo: [NSLocalizedDescriptionKey: "De Markdown-weergave is gestopt."])
        model?.error = "De Markdown-preview is gestopt. Open het document opnieuw om verder te gaan."
        loadedBase = nil
    }

    private func render() {
        guard ready else { return }
        Task {
            do { _ = try await renderBody() }
            catch { model?.error = "Preview kon niet worden bijgewerkt: \(error.localizedDescription)" }
        }
    }

    private func renderBody(showEmptyHint: Bool = true) async throws -> String {
        let result = try await webView.callAsyncJavaScript("""
        const html = DOMPurify.sanitize(marked.parse(source, {gfm:true}), {
          USE_PROFILES: {html:true}, FORBID_TAGS:['style','form','iframe','object','embed','base'], FORBID_ATTR:['style','srcset']
        });
        document.getElementById('content').innerHTML = html || (showEmptyHint ? '<p class="empty">Je tekst krijgt hier vorm.</p>' : '');
        return html;
        """, arguments: ["source": latestText, "showEmptyHint": showEmptyHint], in: nil, contentWorld: .page)
        return result as? String ?? ""
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url else { decisionHandler(.allow); return }
        if let scheme = url.scheme, ["https", "http", "mailto"].contains(scheme) { NSWorkspace.shared.open(url) }
        else if url.scheme == "writer-asset", url.fragment != nil { decisionHandler(.allow); return }
        else if let local = assets.resolve(url), LibraryDisk.extensions.contains(local.pathExtension.lowercased()) { model?.select(local) }
        decisionHandler(.cancel)
    }

    /// Uses an isolated renderer so edits or selection changes cannot alter an export in flight.
    func prepareOutput(text: String, documentURL: URL, root: URL?) async throws -> String {
        latestText = text
        latestURL = documentURL
        assets.root = root
        loadedBase = documentURL.deletingLastPathComponent()
        ready = false
        webView.setFrameSize(NSSize(width: 720, height: 900))
        // Native WebKit printing needs a window-backed view, even with the preview closed.
        let window = NSWindow(contentRect: webView.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = webView
        outputWindow = window
        loadShell()
        let deadline = Date().addingTimeInterval(10)
        while !ready {
            if let loadFailure { throw loadFailure }
            guard Date() < deadline else {
                throw NSError(domain: "RSWriter.Preview", code: 2, userInfo: [NSLocalizedDescriptionKey: "Het voorbereiden van de export duurde te lang. Probeer het opnieuw."])
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        let body = try await renderBody(showEmptyHint: false)
        // Wait for local images before WebKit paginates the print output.
        _ = try await webView.callAsyncJavaScript("""
        await Promise.race([
          Promise.all(Array.from(document.images, image => image.complete ? Promise.resolve() :
            new Promise(resolve => { image.onload = resolve; image.onerror = resolve; }))),
          new Promise(resolve => setTimeout(resolve, 3000))
        ]);
        """, arguments: [:], in: nil, contentWorld: .page)
        return "<!doctype html><html lang=\"nl\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><style>\(Self.css)</style></head><body>\(body)</body></html>"
    }

    func exportHTML(model: WriterModel) { requestOutput(model: model, printInstead: false) }

    func printDocument(model: WriterModel) { requestOutput(model: model, printInstead: true) }

    private func requestOutput(model: WriterModel, printInstead: Bool) {
        guard !preparingOutput, !model.busy, let documentURL = model.selectedURL else { return }
        let text = model.text, root = model.root
        preparingOutput = true
        Task {
            defer { preparingOutput = false }
            do {
                let output = PreviewController()
                let html = try await output.prepareOutput(text: text, documentURL: documentURL, root: root)
                if printInstead { await output.printPreparedDocument() }
                else { try output.saveHTML(html, documentURL: documentURL) }
            } catch { model.error = "Exporteren is mislukt: \(error.localizedDescription)" }
        }
    }

    private func saveHTML(_ html: String, documentURL: URL) throws {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.directoryURL = documentURL.deletingLastPathComponent()
        panel.nameFieldStringValue = documentURL.deletingPathExtension().lastPathComponent + ".html"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try Data(html.utf8).write(to: url, options: .atomic)
    }

    private func printPreparedDocument() async {
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.topMargin = 48; info.bottomMargin = 48; info.leftMargin = 48; info.rightMargin = 48
        let operation = makePrintOperation(info: info)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        _ = await runPrintOperation(operation)
    }

    func makePrintOperation(info: NSPrintInfo) -> NSPrintOperation {
        let operation = webView.printOperation(with: info)
        operation.jobTitle = latestURL?.deletingPathExtension().lastPathComponent
        return operation
    }

    func runPrintOperation(_ operation: NSPrintOperation) async -> Bool {
        guard let window = NSApp.keyWindow ?? outputWindow else { return false }
        return await withCheckedContinuation { continuation in
            printCompletion = continuation
            // Keep WebKit callbacks running while AppKit prepares the pages.
            operation.runModal(for: window, delegate: self, didRun: #selector(printOperationDidRun(_:success:contextInfo:)), contextInfo: nil)
        }
    }

    @objc private func printOperationDidRun(_ operation: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?) {
        printCompletion?.resume(returning: success)
        printCompletion = nil
    }
}

final class LibraryAssets: NSObject, WKURLSchemeHandler {
    var root: URL?
    func resolve(_ url: URL) -> URL? {
        guard url.scheme == "writer-asset", let root else { return nil }
        let candidate = root.appendingPathComponent(url.path).standardizedFileURL.resolvingSymlinksInPath()
        let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath().path
        guard candidate.path.hasPrefix(canonicalRoot + "/") else { return nil }
        return candidate
    }
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url, let file = resolve(url),
              let type = UTType(filenameExtension: file.pathExtension), type.conforms(to: .image),
              let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size < 25_000_000,
              let data = try? Data(contentsOf: file) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist)); return
        }
        urlSchemeTask.didReceive(URLResponse(url: url, mimeType: type.preferredMIMEType ?? "image/png", expectedContentLength: data.count, textEncodingName: nil))
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

struct MarkdownPreview: NSViewRepresentable {
    @ObservedObject var model: WriterModel
    let controller: PreviewController
    func makeNSView(context: Context) -> WKWebView { controller.update(model: model); return controller.webView }
    func updateNSView(_ nsView: WKWebView, context: Context) { controller.update(model: model) }
}
