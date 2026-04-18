import SwiftUI
import WebKit

enum WebViewMode {
    case preview
    case wysiwyg
}

struct MarkdownWebView: NSViewRepresentable {
    let mode: WebViewMode
    let markdown: String
    var onContentChange: ((String) -> Void)?
    var onLinkRequested: (() -> Void)?
    var formattingBridge: FormattingBridge?
    var findBar: FindBarState?
    /// Called once with the coordinator after it's created. Lets parent views wire up
    /// additional behavior (e.g. register with a CompositeFindDriver in Side-by-Side mode).
    var onCoordinatorReady: ((WebViewCoordinator) -> Void)?
    var documentID: UUID?  // Track which document is loaded to detect tab switches

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(mode: mode, onContentChange: onContentChange)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()

        let weakHandler = WeakScriptMessageHandler(delegate: context.coordinator)
        contentController.add(weakHandler, name: "editor")
        config.userContentController = contentController
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        // Connect the formatting bridge to this coordinator
        formattingBridge?.coordinator = context.coordinator

        // Register as the active find driver for this webview's mode.
        // (In Side-by-Side, the composite driver handles coordination.)
        if let findBar = findBar, mode == .wysiwyg {
            findBar.driver = context.coordinator
        }
        // Surface coordinator to parent (used by SideBySideView to capture preview coord).
        onCoordinatorReady?(context.coordinator)

        #if DEBUG
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        #endif

        loadHTMLTemplate(webView: webView, mode: mode)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onContentChange = onContentChange
        context.coordinator.onLinkRequested = onLinkRequested
        formattingBridge?.coordinator = context.coordinator

        // Re-register as find driver (tab switch / mode switch may have changed state).
        // Idempotent — setting every updateNSView call caused a re-render loop.
        if let findBar = findBar, mode == .wysiwyg, findBar.driver !== context.coordinator {
            findBar.driver = context.coordinator
        }

        // If the document changed (tab switch), force-load new content
        if let docID = documentID, docID != context.coordinator.currentDocumentID {
            context.coordinator.currentDocumentID = docID
            context.coordinator.forceLoadMarkdown(markdown)
        } else {
            context.coordinator.pushMarkdown(markdown)
        }
    }

    private func loadHTMLTemplate(webView: WKWebView, mode: WebViewMode) {
        let htmlFile = mode == .preview ? "preview" : "wysiwyg"

        if let resourceURL = AppBundle.resources.url(forResource: htmlFile, withExtension: "html", subdirectory: "Resources") {
            webView.loadFileURL(resourceURL, allowingReadAccessTo: resourceURL.deletingLastPathComponent())
            return
        }

        if let resourceURL = AppBundle.resources.url(forResource: htmlFile, withExtension: "html") {
            webView.loadFileURL(resourceURL, allowingReadAccessTo: resourceURL.deletingLastPathComponent())
            return
        }

        print("Could not find \(htmlFile).html in bundle resources")
    }
}
