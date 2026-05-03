import Foundation
import WebKit

/// Weak wrapper to break the retain cycle between WKUserContentController and the coordinator
class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController,
                                didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

class WebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, FindDriver {
    let mode: WebViewMode
    var onContentChange: ((String) -> Void)?
    var onLinkRequested: (() -> Void)?
    weak var webView: WKWebView?

    var currentDocumentID: UUID?
    private var pendingMarkdown: String?
    private var isLoaded = false
    private var lastPushedMarkdown: String?
    private var hasDeliveredInitialContent = false

    init(mode: WebViewMode, onContentChange: ((String) -> Void)?) {
        self.mode = mode
        self.onContentChange = onContentChange
    }

    func pushMarkdown(_ markdown: String) {
        // In WYSIWYG mode, after the initial content is delivered, the WebView owns the truth.
        // Don't push content back — it would overwrite user edits and reset the cursor.
        if mode == .wysiwyg && hasDeliveredInitialContent {
            return
        }

        guard markdown != lastPushedMarkdown else { return }
        lastPushedMarkdown = markdown

        if isLoaded {
            sendMarkdownToJS(markdown)
            if mode == .wysiwyg { hasDeliveredInitialContent = true }
        } else {
            pendingMarkdown = markdown
        }
    }

    /// Force-load new content (used when switching documents/tabs)
    func forceLoadMarkdown(_ markdown: String) {
        hasDeliveredInitialContent = false
        lastPushedMarkdown = nil
        pushMarkdown(markdown)
    }

    private func sendMarkdownToJS(_ markdown: String) {
        guard let webView = webView else { return }
        // Wrap the string in an array so JSONSerialization accepts it, then extract the inner string
        guard let jsonData = try? JSONSerialization.data(withJSONObject: [markdown]),
              let jsonArray = String(data: jsonData, encoding: .utf8) else { return }
        // jsonArray is like ["the escaped string"] — strip the outer []
        let jsonString = String(jsonArray.dropFirst().dropLast())

        let js: String
        if mode == .preview {
            js = "renderMarkdown(\(jsonString))"
        } else {
            // Pass current document ID so the JS side can save/restore caret position
            // per-document across tab switches.
            let docId = currentDocumentID?.uuidString ?? ""
            js = "loadMarkdown(\(jsonString), \"\(docId)\")"
        }
        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                print("JS error: \(error)")
            }
        }
    }

    // MARK: - Formatting Commands

    func executeFormatting(_ command: String) {
        guard let webView = webView, isLoaded else { return }
        webView.evaluateJavaScript("insertFormatting('\(command)')") { _, error in
            if let error = error {
                print("Formatting error: \(error)")
            }
        }
    }

    func insertLink(url: String, text: String) {
        guard let webView = webView, isLoaded else { return }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: [url, text]),
              let jsonArray = String(data: jsonData, encoding: .utf8) else { return }
        let args = String(jsonArray.dropFirst().dropLast()) // "url","text"
        webView.evaluateJavaScript("insertLink(\(args))") { _, error in
            if let error = error {
                print("Insert link error: \(error)")
            }
        }
    }

    // MARK: - FindDriver

    /// JSON-encode a single string so it can be interpolated into a JS call as a literal.
    /// Reuses the same trick as sendMarkdownToJS.
    private func jsString(_ s: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [s]),
              let array = String(data: data, encoding: .utf8) else { return "\"\"" }
        return String(array.dropFirst().dropLast())
    }

    func applySearch(query: String, caseSensitive: Bool, completion: @escaping (Int) -> Void) {
        guard let webView = webView, isLoaded else { completion(0); return }
        let js = "findAll(\(jsString(query)), \(caseSensitive))"
        webView.evaluateJavaScript(js) { result, _ in
            completion((result as? Int) ?? 0)
        }
    }

    func jumpTo(matchIndex: Int) {
        guard let webView = webView, isLoaded else { return }
        webView.evaluateJavaScript("jumpToMatch(\(matchIndex))") { _, _ in }
    }

    func clearSearch() {
        guard let webView = webView, isLoaded else { return }
        webView.evaluateJavaScript("clearFind()") { _, _ in }
    }

    func replaceCurrentMatch(with replacement: String, completion: @escaping (Bool) -> Void) {
        // Preview is read-only — fail quietly so users can still search there.
        guard mode == .wysiwyg, let webView = webView, isLoaded else { completion(false); return }
        let js = "replaceCurrent(\(jsString(replacement)))"
        webView.evaluateJavaScript(js) { result, _ in
            completion((result as? Bool) ?? false)
        }
    }

    func replaceAll(query: String, with replacement: String, caseSensitive: Bool,
                    completion: @escaping (Int) -> Void) {
        guard mode == .wysiwyg, let webView = webView, isLoaded else { completion(0); return }
        let js = "replaceAll(\(jsString(query)), \(jsString(replacement)), \(caseSensitive))"
        webView.evaluateJavaScript(js) { result, _ in
            completion((result as? Int) ?? 0)
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoaded = true
        if let pending = pendingMarkdown {
            pendingMarkdown = nil
            sendMarkdownToJS(pending)
            if mode == .wysiwyg { hasDeliveredInitialContent = true }
        }
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController,
                                didReceive message: WKScriptMessage) {
        guard message.name == "editor" else { return }

        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        if type == "contentChanged", let markdown = body["markdown"] as? String {
            lastPushedMarkdown = markdown
            DispatchQueue.main.async { [weak self] in
                self?.onContentChange?(markdown)
            }
        } else if type == "requestLink" {
            DispatchQueue.main.async { [weak self] in
                self?.onLinkRequested?()
            }
        }
    }
}
