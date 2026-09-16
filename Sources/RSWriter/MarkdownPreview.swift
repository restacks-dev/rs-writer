import SwiftUI
import WebKit
import UniformTypeIdentifiers

@MainActor
final class PreviewController: NSObject, ObservableObject, WKNavigationDelegate {
    let webView: WKWebView
    private let assets = LibraryAssets()
    private var ready = false
    private var latestText = ""
    private var latestURL: URL?
    private var loadedBase: URL?
    private weak var model: WriterModel?
    private static let css = """
    :root{color-scheme:light dark;--ink:#262723;--paper:#fff;--muted:#777b77;--line:#e5e7e3;--accent:#168586}
    @media(prefers-color-scheme:dark){:root{--ink:#dadcd7;--paper:#1e201f;--muted:#959b95;--line:#3b403c;--accent:#73c6c3}}
    *{box-sizing:border-box}html{background:var(--paper);color:var(--ink)}body{max-width:780px;margin:0 auto;padding:48px 44px 100px;font:19px/1.75 Charter,Georgia,serif;overflow-wrap:break-word}
    h1,h2,h3,h4,h5,h6{font-family:-apple-system,BlinkMacSystemFont,sans-serif;line-height:1.3;letter-spacing:-.025em;margin:1.5em 0 .6em}h1{font-size:2em;margin-top:0}h2{font-size:1.5em}h3{font-size:1.2em}p{margin:0 0 1.1em}a{color:var(--accent);text-underline-offset:3px}blockquote{margin:1.4em 0;padding:0 0 0 1.2em;border-left:3px solid var(--accent);color:var(--muted)}pre,code{font: .83em/1.65 ui-monospace,Menlo,monospace}code{padding:.15em .35em;background:color-mix(in srgb,var(--ink) 5%,transparent);border-radius:3px}pre{padding:20px;overflow:auto;border:1px solid var(--line);border-radius:6px}pre code{padding:0;background:none;font-size:1em}hr{border:0;border-top:1px solid var(--line);margin:2em 0}img{max-width:100%;height:auto}table{width:100%;border-collapse:collapse;font: .85em/1.5 -apple-system,sans-serif;margin:1.5em 0}th,td{text-align:left;border-bottom:1px solid var(--line);padding:10px}th{font-weight:600}li{margin:.25em 0}input{accent-color:var(--accent)}.empty{color:var(--muted);font-style:italic}
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
        guard let url = Bundle.main.url(forResource: name, withExtension: ext), let source = try? String(contentsOf: url) else { return "" }
        return source
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { ready = true; render() }

    private func render() {
        guard ready else { return }
        Task {
        do { _ = try await webView.callAsyncJavaScript("""
        const html = DOMPurify.sanitize(marked.parse(source, {gfm:true}), {
          USE_PROFILES: {html:true}, FORBID_TAGS:['style','form','iframe','object','embed','base'], FORBID_ATTR:['style','srcset']
        });
        document.getElementById('content').innerHTML = html || '<p class="empty">Je tekst krijgt hier vorm.</p>';
        """, arguments: ["source": latestText], in: nil, contentWorld: .page)
        } catch { model?.error = "Preview kon niet worden bijgewerkt: \(error.localizedDescription)" }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url else { decisionHandler(.allow); return }
        if let scheme = url.scheme, ["https", "http", "mailto"].contains(scheme) { NSWorkspace.shared.open(url) }
        else if url.scheme == "writer-asset", url.fragment != nil { decisionHandler(.allow); return }
        else if let local = assets.resolve(url), LibraryDisk.extensions.contains(local.pathExtension.lowercased()) { model?.select(local) }
        decisionHandler(.cancel)
    }

    func exportHTML() {
        guard ready else { model?.error = "Wacht tot de preview geladen is."; return }
        webView.evaluateJavaScript("document.getElementById('content').innerHTML") { [weak self] value, error in
            guard let self else { return }
            guard let body = value as? String else { self.model?.error = error?.localizedDescription ?? "Export mislukt."; return }
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.html]
            panel.directoryURL = self.latestURL?.deletingLastPathComponent()
            panel.nameFieldStringValue = (self.latestURL?.deletingPathExtension().lastPathComponent ?? "Document") + ".html"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            let html = "<!doctype html><html lang=\"nl\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><style>\(Self.css)</style></head><body>\(body)</body></html>"
            do { try Data(html.utf8).write(to: url, options: .atomic) }
            catch { self.model?.error = error.localizedDescription }
        }
    }

    func printDocument() {
        guard ready else { model?.error = "Wacht tot de preview geladen is."; return }
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.topMargin = 48; info.bottomMargin = 48; info.leftMargin = 48; info.rightMargin = 48
        let operation = webView.printOperation(with: info)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        if let window = NSApp.keyWindow { operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil) }
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
