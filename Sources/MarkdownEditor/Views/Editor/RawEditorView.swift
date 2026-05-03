import SwiftUI
import AppKit

struct RawEditorView: NSViewRepresentable {
    @Binding var text: String
    /// Optional find-bar state. When non-nil, this view's coordinator registers itself as
    /// the driver whenever it appears and re-searches on text changes.
    var findBar: FindBarState?
    /// Called once with the coordinator so parent views (like SideBySideView) can wire
    /// it into a CompositeFindDriver.
    var onCoordinatorReady: ((FindDriver) -> Void)? = nil

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
        // We run our own unified find bar; disable Apple's to avoid double UI on Cmd+F.
        textView.usesFindBar = false
        textView.isIncrementalSearchingEnabled = false
        textView.textContainerInset = NSSize(width: 16, height: 16)

        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .textColor

        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        textView.string = text
        context.coordinator.applyHighlighting()

        // Register as the find driver when the view is created.
        context.coordinator.registerAsFindDriver()

        // Surface coordinator to parent.
        onCoordinatorReady?(context.coordinator)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView

        // CRITICAL ORDERING: update `parent` BEFORE touching textView.string.
        // Setting textView.string fires NSTextDidChangeNotification synchronously,
        // which calls our textDidChange delegate, which writes textView.string back
        // through `parent.text`. If `parent` is still the previous tab's RawEditorView
        // here, that write goes into the WRONG document and corrupts it (silent data
        // loss — manifests as the previous tab's file saving as empty).
        context.coordinator.parent = self

        if textView.string != text && !context.coordinator.isUpdating {
            let selection = textView.selectedRanges
            // Tell textDidChange this is a programmatic write so it doesn't echo back.
            context.coordinator.isUpdating = true
            textView.string = text
            context.coordinator.applyHighlighting()
            textView.selectedRanges = selection
            context.coordinator.isUpdating = false
        }

        context.coordinator.registerAsFindDriver()
    }

    class Coordinator: NSObject, NSTextViewDelegate, FindDriver {
        var parent: RawEditorView
        var isUpdating = false
        weak var textView: NSTextView?
        private let highlighter = MarkdownHighlighter()
        private let highlightDebouncer = Debouncer(delay: 0.1)
        private let findDebouncer = Debouncer(delay: 0.2)

        // Find state
        private var matchRanges: [NSRange] = []
        private var currentMatchIndex: Int = -1
        private let matchColor = NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.56, alpha: 1.0)
        private let currentMatchColor = NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.26, alpha: 1.0)

        init(_ parent: RawEditorView) {
            self.parent = parent
        }

        func registerAsFindDriver() {
            guard let bar = parent.findBar else { return }
            // Idempotent — setting the driver every updateNSView triggered a body/update loop.
            if bar.driver !== self {
                bar.driver = self
                if bar.isVisible, !bar.query.isEmpty {
                    bar.refreshSearch()
                }
            }
        }

        func textDidChange(_ notification: Notification) {
            // Skip if this notification was caused by our own programmatic update in
            // updateNSView — otherwise we'd echo the new tab's content back through
            // the old tab's binding (data loss).
            guard !isUpdating else { return }
            guard let textView = notification.object as? NSTextView else { return }
            isUpdating = true
            parent.text = textView.string
            isUpdating = false

            highlightDebouncer.debounce { [weak self] in
                self?.applyHighlighting()
            }

            // Re-run find if the bar is visible (text edits invalidate match ranges).
            if let bar = parent.findBar, bar.isVisible, !bar.query.isEmpty {
                findDebouncer.debounce { [weak self] in
                    self?.parent.findBar?.refreshSearch()
                }
            }
        }

        func applyHighlighting() {
            guard let textView = textView,
                  let textStorage = textView.textStorage else { return }
            highlighter.highlight(textStorage)
            // Re-apply find highlights on top (the highlighter only resets font/foreground).
            reapplyFindHighlights()
        }

        private func reapplyFindHighlights() {
            guard let textStorage = textView?.textStorage else { return }
            for (i, range) in matchRanges.enumerated() {
                let color = i == currentMatchIndex ? currentMatchColor : matchColor
                textStorage.addAttribute(.backgroundColor, value: color, range: range)
            }
        }

        // MARK: - FindDriver

        func applySearch(query: String, caseSensitive: Bool, completion: @escaping (Int) -> Void) {
            completion(applySearchSync(query: query, caseSensitive: caseSensitive))
        }

        private func applySearchSync(query: String, caseSensitive: Bool) -> Int {
            guard let textView = textView, let textStorage = textView.textStorage else { return 0 }
            // Clear previous
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            textStorage.removeAttribute(.backgroundColor, range: fullRange)
            matchRanges = []
            currentMatchIndex = -1

            guard !query.isEmpty else { return 0 }

            let pattern = NSRegularExpression.escapedPattern(for: query)
            let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return 0 }

            regex.enumerateMatches(in: textView.string, options: [], range: fullRange) { match, _, _ in
                if let r = match?.range { matchRanges.append(r) }
            }

            for range in matchRanges {
                textStorage.addAttribute(.backgroundColor, value: matchColor, range: range)
            }
            return matchRanges.count
        }

        func jumpTo(matchIndex: Int) {
            guard let textView = textView,
                  let textStorage = textView.textStorage,
                  matchIndex >= 0, matchIndex < matchRanges.count else { return }

            // Revert previous current to plain match color
            if currentMatchIndex >= 0, currentMatchIndex < matchRanges.count {
                textStorage.addAttribute(.backgroundColor, value: matchColor,
                                         range: matchRanges[currentMatchIndex])
            }
            currentMatchIndex = matchIndex
            let range = matchRanges[matchIndex]
            textStorage.addAttribute(.backgroundColor, value: currentMatchColor, range: range)
            textView.scrollRangeToVisible(range)
            textView.setSelectedRange(range)
        }

        func clearSearch() {
            guard let textView = textView, let textStorage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            textStorage.removeAttribute(.backgroundColor, range: fullRange)
            matchRanges = []
            currentMatchIndex = -1
        }

        func replaceCurrentMatch(with replacement: String, completion: @escaping (Bool) -> Void) {
            guard let textView = textView,
                  currentMatchIndex >= 0, currentMatchIndex < matchRanges.count else {
                completion(false)
                return
            }
            let range = matchRanges[currentMatchIndex]
            guard textView.shouldChangeText(in: range, replacementString: replacement) else {
                completion(false)
                return
            }
            textView.textStorage?.replaceCharacters(in: range, with: replacement)
            textView.didChangeText()
            completion(true)
        }

        func replaceAll(query: String, with replacement: String, caseSensitive: Bool,
                        completion: @escaping (Int) -> Void) {
            guard let textView = textView, !query.isEmpty else { completion(0); return }
            let pattern = NSRegularExpression.escapedPattern(for: query)
            let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
                completion(0); return
            }

            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            let matches = regex.matches(in: textView.string, options: [], range: fullRange)
            guard !matches.isEmpty else { completion(0); return }

            // Back-to-front so earlier ranges don't shift.
            textView.undoManager?.beginUndoGrouping()
            for match in matches.reversed() {
                let range = match.range
                if textView.shouldChangeText(in: range, replacementString: replacement) {
                    textView.textStorage?.replaceCharacters(in: range, with: replacement)
                    textView.didChangeText()
                }
            }
            textView.undoManager?.endUndoGrouping()
            completion(matches.count)
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
