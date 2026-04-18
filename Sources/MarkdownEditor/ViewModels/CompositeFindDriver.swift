import Foundation

/// Forwards find operations to multiple drivers simultaneously. Used in Side-by-Side mode
/// where both the raw editor and the preview WebView need to reflect the same search.
///
/// Replace operations forward only to `primary` (the raw editor); the preview then
/// re-renders from the updated markdown and the composite re-applies the search.
final class CompositeFindDriver: FindDriver {
    weak var primary: FindDriver?          // the raw editor (writable)
    weak var secondary: FindDriver?        // the preview WebView (read-only)

    func applySearch(query: String, caseSensitive: Bool, completion: @escaping (Int) -> Void) {
        var primaryCount = 0
        let group = DispatchGroup()

        if let p = primary {
            group.enter()
            p.applySearch(query: query, caseSensitive: caseSensitive) { n in
                primaryCount = n
                group.leave()
            }
        }
        if let s = secondary {
            group.enter()
            s.applySearch(query: query, caseSensitive: caseSensitive) { _ in
                group.leave()
            }
        }
        group.notify(queue: .main) {
            // Report the primary's count — it's the authoritative source. If absent, the secondary's.
            completion(primaryCount)
        }
    }

    func jumpTo(matchIndex: Int) {
        primary?.jumpTo(matchIndex: matchIndex)
        secondary?.jumpTo(matchIndex: matchIndex)
    }

    func clearSearch() {
        primary?.clearSearch()
        secondary?.clearSearch()
    }

    func replaceCurrentMatch(with replacement: String, completion: @escaping (Bool) -> Void) {
        guard let primary = primary else { completion(false); return }
        primary.replaceCurrentMatch(with: replacement, completion: completion)
    }

    func replaceAll(query: String, with replacement: String, caseSensitive: Bool,
                    completion: @escaping (Int) -> Void) {
        guard let primary = primary else { completion(0); return }
        primary.replaceAll(query: query, with: replacement, caseSensitive: caseSensitive,
                           completion: completion)
    }
}
