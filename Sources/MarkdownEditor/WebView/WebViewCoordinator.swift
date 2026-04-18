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

class WebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
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

        let functionName = mode == .preview ? "renderMarkdown" : "loadMarkdown"
        webView.evaluateJavaScript("\(functionName)(\(jsonString))") { _, error in
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
