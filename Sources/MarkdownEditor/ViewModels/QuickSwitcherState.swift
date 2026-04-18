import Foundation

/// State for the Cmd+P quick file switcher palette. Lives on `Workspace` so the
/// AppCommands menu can toggle it from anywhere without needing a view reference.
@Observable
final class QuickSwitcherState {
    var isVisible: Bool = false
    var query: String = ""
    /// Bumped whenever `open()` is called so the view can force-grab focus even when
    /// the palette was already visible (repeat Cmd+P in VS Code convention).
    var requestFocusToken: Int = 0

    /// Current result list, ordered by score descending. Not observed — the view reads
    /// it imperatively whenever `query` or the source file list changes.
    @ObservationIgnored
    var results: [FileNode] = []

    @ObservationIgnored
    var selectedIndex: Int = 0

    // MARK: - User actions

    func open() {
        isVisible = true
        requestFocusToken &+= 1
    }

    func close() {
        isVisible = false
        query = ""
        results = []
        selectedIndex = 0
    }

    func selectNext() {
        guard !results.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % results.count
    }

    func selectPrevious() {
        guard !results.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + results.count) % results.count
    }

    /// Recompute `results` from the given flat list of files and the current `query`.
    /// Empty query → show all files (up to 50) ordered by recency (caller sorts input).
    func recomputeResults(from files: [FileNode], rootURL: URL?) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            // Show everything, capped. Caller passes files in a useful order (e.g. recent first).
            results = Array(files.prefix(50))
            selectedIndex = 0
            return
        }

        // Score each file: filename first, fall back to path for a smaller max score.
        var scored: [(file: FileNode, score: Int)] = []
        for f in files {
            let filenameScore = FuzzyMatcher.score(query: trimmed, in: f.name) ?? Int.min
            let pathScore: Int
            if let root = rootURL {
                let relPath = f.url.path.replacingOccurrences(of: root.path + "/", with: "")
                pathScore = FuzzyMatcher.score(query: trimmed, in: relPath) ?? Int.min
            } else {
                pathScore = Int.min
            }
            // Bias filename matches ahead of path-only matches by a large constant.
            let effective: Int
            if filenameScore != Int.min {
                effective = filenameScore + 1_000
            } else if pathScore != Int.min {
                effective = pathScore
            } else {
                continue
            }
            scored.append((f, effective))
        }

        scored.sort { $0.score > $1.score }
        results = scored.prefix(50).map { $0.file }
        selectedIndex = 0
    }

    var selectedFile: FileNode? {
        guard selectedIndex >= 0, selectedIndex < results.count else { return nil }
        return results[selectedIndex]
    }
}
