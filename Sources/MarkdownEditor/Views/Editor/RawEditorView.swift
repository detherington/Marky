import SwiftUI
import AppKit

struct RawEditorView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = MarkdownTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isRichText = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.textContainerInset = NSSize(width: 16, height: 16)

        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .textColor

        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        textView.string = text
        context.coordinator.applyHighlighting()

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        if textView.string != text && !context.coordinator.isUpdating {
            let selection = textView.selectedRanges
            textView.string = text
            context.coordinator.applyHighlighting()
            textView.selectedRanges = selection
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RawEditorView
        var isUpdating = false
        weak var textView: NSTextView?
        private let highlighter = MarkdownHighlighter()
        private let highlightDebouncer = Debouncer(delay: 0.1)

        init(_ parent: RawEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isUpdating = true
            parent.text = textView.string
            isUpdating = false

            highlightDebouncer.debounce { [weak self] in
                self?.applyHighlighting()
            }
        }

        func applyHighlighting() {
            guard let textView = textView,
                  let textStorage = textView.textStorage else { return }
            highlighter.highlight(textStorage)
        }
    }
}

/// Custom NSTextView subclass that intercepts keyboard shortcuts for markdown formatting
class MarkdownTextView: NSTextView {

    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.contains(.command) else {
            super.keyDown(with: event)
            return
        }

        let chars = event.charactersIgnoringModifiers ?? ""

        switch chars {
        case "b":
            wrapSelection(prefix: "**", suffix: "**")
        case "i":
            wrapSelection(prefix: "*", suffix: "*")
        case "e":
            wrapSelection(prefix: "`", suffix: "`")
        case "k":
            insertLink()
        case "d":
            if event.modifierFlags.contains(.shift) {
                super.keyDown(with: event)
            } else {
                wrapSelection(prefix: "~~", suffix: "~~")
            }
        default:
            super.keyDown(with: event)
        }
    }

    private func wrapSelection(prefix: String, suffix: String) {
        let range = selectedRange()
        let nsString = string as NSString

        if range.length > 0 {
            let selected = nsString.substring(with: range)

            // If already wrapped, unwrap
            let prefixLen = prefix.count
            let suffixLen = suffix.count
            if selected.hasPrefix(prefix) && selected.hasSuffix(suffix) && selected.count >= prefixLen + suffixLen {
                let start = selected.index(selected.startIndex, offsetBy: prefixLen)
                let end = selected.index(selected.endIndex, offsetBy: -suffixLen)
                let unwrapped = String(selected[start..<end])
                insertText(unwrapped, replacementRange: range)
                return
            }

            // Check if the surrounding text has the markers (e.g., cursor selected inside **bold**)
            let extStart = max(0, range.location - prefixLen)
            let extEnd = min(nsString.length, range.location + range.length + suffixLen)
            let beforeRange = NSRange(location: extStart, length: prefixLen)
            let afterRange = NSRange(location: range.location + range.length, length: min(suffixLen, nsString.length - (range.location + range.length)))

            if extStart >= 0 && extEnd <= nsString.length &&
                beforeRange.location + beforeRange.length <= nsString.length &&
                afterRange.location + afterRange.length <= nsString.length {
                let before = nsString.substring(with: beforeRange)
                let after = nsString.substring(with: afterRange)
                if before == prefix && after == suffix {
                    // Remove surrounding markers
                    let fullRange = NSRange(location: extStart, length: extEnd - extStart)
                    insertText(selected, replacementRange: fullRange)
                    return
                }
            }

            // Wrap the selection
            let wrapped = prefix + selected + suffix
            insertText(wrapped, replacementRange: range)
            // Select just the text inside the markers
            setSelectedRange(NSRange(location: range.location + prefixLen, length: range.length))
        } else {
            // No selection — insert markers and place cursor between them
            let insertion = prefix + suffix
            insertText(insertion, replacementRange: range)
            setSelectedRange(NSRange(location: range.location + prefix.count, length: 0))
        }
    }

    private func insertLink() {
        let range = selectedRange()
        let nsString = string as NSString
        let selectedText = range.length > 0 ? nsString.substring(with: range) : ""

        let alert = NSAlert()
        alert.messageText = "Insert Link"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Insert")
        alert.addButton(withTitle: "Cancel")

        let urlField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        urlField.placeholderString = "URL"

        alert.accessoryView = urlField
        alert.window.initialFirstResponder = urlField

        if alert.runModal() == .alertFirstButtonReturn {
            let url = urlField.stringValue
            if !url.isEmpty {
                let text = selectedText.isEmpty ? url : selectedText
                let markdown = "[\(text)](\(url))"
                insertText(markdown, replacementRange: range)
            }
        }
    }

    // Need to override to create instances of MarkdownTextView instead of NSTextView
    override class var defaultMenu: NSMenu? { NSTextView.defaultMenu }

    override class func scrollableTextView() -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]

        let contentSize = scrollView.contentSize
        let textView = MarkdownTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        return scrollView
    }
}
