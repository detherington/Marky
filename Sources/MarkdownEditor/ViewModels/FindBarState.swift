import Foundation

/// Operations each editor mode must implement to participate in Find & Replace.
/// Implemented by RawEditorView.Coordinator, WebViewCoordinator, and CompositeFindDriver.
/// Count-returning methods use a completion because WebView variants are async
/// (evaluateJavaScript is async). Native NSTextView drivers can complete synchronously.
protocol FindDriver: AnyObject {
    /// Search for `query` and highlight all matches. Completion receives total match count.
    func applySearch(query: String, caseSensitive: Bool, completion: @escaping (Int) -> Void)

    /// Highlight the match at 0-based index as "current" and scroll to it.
    func jumpTo(matchIndex: Int)

    /// Remove all find highlights.
    func clearSearch()

    /// Replace the currently-highlighted match with `replacement`.
    func replaceCurrentMatch(with replacement: String, completion: @escaping (Bool) -> Void)

    /// Replace every match of `query` with `replacement`. Completion receives count replaced.
    func replaceAll(query: String, with replacement: String, caseSensitive: Bool, completion: @escaping (Int) -> Void)
}

/// Shared state for Marky's unified Find & Replace bar.
/// Persists across tab switches so the user's search sticks as they navigate — this
/// matches behavior in Xcode, VS Code, etc.
@Observable
final class FindBarState {
    var isVisible: Bool = false
    var isReplaceMode: Bool = false
    var query: String = ""
    var replacement: String = ""
    var caseSensitive: Bool = false
    var matchCount: Int = 0
    /// 1-indexed current match for display. 0 means "no current match".
    var currentMatch: Int = 0
    /// Bumped when the bar should take focus — observed by FindBarView to re-grab focus
    /// even when the bar is already visible (e.g. user pressed Cmd+F again).
    var requestFocusToken: Int = 0

    /// Weak reference — the active editor's coordinator registers itself when it appears.
    /// `@ObservationIgnored` because mutating this should NOT cause SwiftUI body re-evaluation
    /// (we had a re-render loop when driver changes triggered Representable updateNSView,
    /// which in turn set driver again).
    @ObservationIgnored
    weak var driver: FindDriver?
    /// Stable composite driver used in Side-by-Side mode. Owned here (not in the view) so
    /// it survives SwiftUI body re-evaluations and guarantees both panes register into the
    /// same instance.
    @ObservationIgnored
    let sideBySideComposite = CompositeFindDriver()

    // MARK: - User-facing actions

    func open(replaceMode: Bool) {
        isReplaceMode = replaceMode
        isVisible = true
        requestFocusToken &+= 1
    }

    func close() {
        isVisible = false
        driver?.clearSearch()
        matchCount = 0
        currentMatch = 0
    }

    /// Called whenever the query changes (or the driver changes, e.g. after tab switch).
    /// Re-runs the search on the current driver and jumps to the first match.
    func refreshSearch() {
        guard let driver = driver else {
            matchCount = 0
            currentMatch = 0
            return
        }
        guard !query.isEmpty else {
            driver.clearSearch()
            matchCount = 0
            currentMatch = 0
            return
        }
        driver.applySearch(query: query, caseSensitive: caseSensitive) { [weak self] total in
            guard let self = self else { return }
            self.matchCount = total
            if total > 0 {
                self.currentMatch = 1
                driver.jumpTo(matchIndex: 0)
            } else {
                self.currentMatch = 0
            }
        }
    }

    func jumpNext() {
        guard let driver = driver, matchCount > 0 else { return }
        let next = currentMatch >= matchCount ? 1 : currentMatch + 1
        currentMatch = next
        driver.jumpTo(matchIndex: next - 1)
    }

    func jumpPrevious() {
        guard let driver = driver, matchCount > 0 else { return }
        let prev = currentMatch <= 1 ? matchCount : currentMatch - 1
        currentMatch = prev
        driver.jumpTo(matchIndex: prev - 1)
    }

    func replaceCurrent() {
        guard let driver = driver, matchCount > 0 else { return }
        let oldIndex = currentMatch
        driver.replaceCurrentMatch(with: replacement) { [weak self] success in
            guard let self = self, success else { return }
            // Match ranges have shifted — re-search and try to stay near the old position.
            self.refreshSearch()
            // refreshSearch jumps to index 0; correct that after it completes (next tick).
            DispatchQueue.main.async {
                if self.matchCount > 0 {
                    let target = min(oldIndex, self.matchCount)
                    self.currentMatch = target
                    self.driver?.jumpTo(matchIndex: target - 1)
                }
            }
        }
    }

    func replaceAll() {
        guard let driver = driver else { return }
        driver.replaceAll(query: query, with: replacement, caseSensitive: caseSensitive) { [weak self] _ in
            self?.refreshSearch()
        }
    }
}
