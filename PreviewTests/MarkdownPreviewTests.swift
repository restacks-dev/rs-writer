import AppKit
import WebKit
import PDFKit

// Exercise the real preview in a separately identified, sandboxed app bundle.
@main @MainActor
struct MarkdownPreviewTests {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        DispatchQueue.main.asyncAfter(deadline: .now() + 40) {
            print("FAIL: sandboxed Markdown preview timed out")
            exit(1)
        }
        Task { @MainActor in
            do { try await runChecks(); exit(0) }
            catch { print("FAIL: \(error)"); exit(1) }
        }
        app.run()
    }

    private static func runChecks() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = WriterModel(defaults: .standard, startAutomatically: false)
        model.root = directory
        model.selectedURL = directory.appendingPathComponent("First.md")
        model.text = "# Preview check\n\nThis is **bold**.\n\n- [x] Done\n\n| A | B |\n| - | - |\n| 1 | 2 |"
        let preview = PreviewController()
        preview.update(model: model)
        preview.update(model: model)
        try await waitFor(preview, model: model, "document.querySelector('h1')?.textContent === 'Preview check' && document.querySelector('strong')?.textContent === 'bold' && document.querySelector('input[type=checkbox]')?.checked === true && document.querySelectorAll('td').length === 2")

        model.text = "Just plain text, updated live."
        preview.update(model: model)
        try await waitFor(preview, model: model, "document.querySelector('#content')?.textContent.trim() === 'Just plain text, updated live.' && !document.querySelector('h1')")

        model.text = "# Safe\n\n<script>window.previewAttack = true</script><img src=missing.png onerror='window.previewAttack=true'>"
        preview.update(model: model)
        try await waitFor(preview, model: model, "document.querySelector('h1')?.textContent === 'Safe' && document.querySelectorAll('#content script, #content [onerror]').length === 0 && window.previewAttack !== true")

        let nested = directory.appendingPathComponent("Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        // A tiny fixture generated locally; no network resources are required.
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 4, bitsPerPixel: 32)!
        try bitmap.representation(using: .png, properties: [:])!.write(to: nested.appendingPathComponent("pixel.png"))
        model.selectedURL = nested.appendingPathComponent("Second.md")
        model.text = "# Nested document\n\n![Local image](pixel.png)"
        preview.update(model: model)
        try await waitFor(preview, model: model, "document.querySelector('h1')?.textContent === 'Nested document' && document.querySelector('#content img')?.naturalWidth === 1")

        model.text = ""
        preview.update(model: model)
        try await waitFor(preview, model: model, "document.querySelector('#content .empty') !== null")

        let output = PreviewController()
        let html = try await output.prepareOutput(text: "# Latest unsaved text\n\nExport **this**. <script>window.previewAttack=true</script>", documentURL: directory.appendingPathComponent("Export.md"), root: directory)
        guard html.contains("<h1>Latest unsaved text</h1>"), html.contains("<strong>this</strong>"), !html.contains("<script>") else {
            throw NSError(domain: "PreviewTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cold HTML export did not render the requested snapshot"])
        }
        let pdf = try await output.webView.pdf(configuration: WKPDFConfiguration())
        guard PDFDocument(data: pdf)?.string?.contains("Latest unsaved text") == true else {
            throw NSError(domain: "PreviewTests", code: 4, userInfo: [NSLocalizedDescriptionKey: "Prepared print view did not contain the current document"])
        }
        let printURL = directory.appendingPathComponent("Printed.pdf")
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = printURL
        let operation = output.makePrintOperation(info: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        guard await output.runPrintOperation(operation), PDFDocument(url: printURL)?.string?.contains("Latest unsaved text") == true else {
            throw NSError(domain: "PreviewTests", code: 6, userInfo: [NSLocalizedDescriptionKey: "Native print operation produced no document text"])
        }
        let emptyOutput = PreviewController()
        let emptyHTML = try await emptyOutput.prepareOutput(text: "", documentURL: directory.appendingPathComponent("Empty.md"), root: directory)
        let emptyBody = try await emptyOutput.webView.evaluateJavaScript("document.querySelector('#content').innerHTML") as? String
        guard emptyHTML.contains("<body></body>"), emptyBody == "" else {
            throw NSError(domain: "PreviewTests", code: 5, userInfo: [NSLocalizedDescriptionKey: "Empty output must not print preview placeholder text"])
        }
        print("Passed sandboxed preview and output checks: rendering, live updates, sanitization, document switch, local image, cold HTML/PDF preparation, native print-to-PDF and empty output.")
    }

    private static func waitFor(_ preview: PreviewController, model: WriterModel, _ condition: String) async throws {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if let error = model.error { throw NSError(domain: "PreviewTests", code: 1, userInfo: [NSLocalizedDescriptionKey: error]) }
            if let result = try? await preview.webView.evaluateJavaScript(condition), result as? Bool == true { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw NSError(domain: "PreviewTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "Preview condition timed out: \(condition)"])
    }
}
