import Foundation

/// Shared bridge between the formatting toolbar and the WKWebView coordinator.
/// The toolbar calls methods here; the coordinator is set when the WebView is created.
@Observable
final class FormattingBridge {
    weak var coordinator: WebViewCoordinator?

    func bold() { coordinator?.executeFormatting("bold") }
    func italic() { coordinator?.executeFormatting("italic") }
    func code() { coordinator?.executeFormatting("code") }
    func heading(_ level: Int) { coordinator?.executeFormatting("h\(level)") }
    func unorderedList() { coordinator?.executeFormatting("ul") }
    func orderedList() { coordinator?.executeFormatting("ol") }
    func blockquote() { coordinator?.executeFormatting("blockquote") }
    func horizontalRule() { coordinator?.executeFormatting("hr") }
    func paragraph() { coordinator?.executeFormatting("paragraph") }
    func strikethrough() { coordinator?.executeFormatting("strikethrough") }
    func insertLink(url: String, text: String) { coordinator?.insertLink(url: url, text: text) }
}
