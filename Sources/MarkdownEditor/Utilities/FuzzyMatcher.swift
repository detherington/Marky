import Foundation

/// Simple fuzzy subsequence matcher with scoring, good enough for Cmd+P.
/// Returns `nil` when `query` doesn't appear as a subsequence of `candidate` (case-insensitive),
/// or an integer score where higher means a better match.
///
/// Scoring heuristics:
/// - +20 for each char that matches the very start of the candidate
/// - +8 for each char that matches immediately after a separator (space, -, _, ., /)
/// - +cumulative (1, 2, 3, …) for consecutive-char streaks
/// - +1 for each match overall
/// - shorter candidates get a small bonus (we normalize by length at the end)
enum FuzzyMatcher {
    private static let separators: Set<Character> = [" ", "-", "_", ".", "/", "\\"]

    static func score(query: String, in candidate: String) -> Int? {
        guard !query.isEmpty else { return 0 }
        let q = Array(query.lowercased())
        let c = Array(candidate.lowercased())
        guard q.count <= c.count else { return nil }

        var qIndex = 0
        var score = 0
        var streak = 0
        var lastMatch: Int = -2 // ensures first match isn't treated as consecutive

        for ci in 0..<c.count {
            if qIndex == q.count { break }
            if c[ci] == q[qIndex] {
                // Start-of-string bonus
                if ci == 0 {
                    score += 20
                } else if separators.contains(c[ci - 1]) {
                    score += 8
                }
                // Consecutive streak bonus (+1, +2, +3, ...)
                if ci == lastMatch + 1 {
                    streak += 1
                    score += streak
                } else {
                    streak = 0
                }
                score += 1
                lastMatch = ci
                qIndex += 1
            }
        }

        guard qIndex == q.count else { return nil }

        // Shorter candidates get a small edge (max 10 points for very short names).
        score += max(0, 10 - c.count / 4)
        return score
    }
}
