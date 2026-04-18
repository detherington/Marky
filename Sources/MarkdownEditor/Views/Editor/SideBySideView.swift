import SwiftUI

struct SideBySideView: View {
    @Bindable var document: DocumentViewModel
    var findBar: FindBarState? = nil

    var body: some View {
        HSplitView {
            RawEditorView(
                text: $document.content,
                findBar: nil,
                onCoordinatorReady: { driver in
                    guard let bar = findBar else { return }
                    bar.sideBySideComposite.primary = driver
                    bar.driver = bar.sideBySideComposite
                    if bar.isVisible, !bar.query.isEmpty { bar.refreshSearch() }
                }
            )
            .frame(minWidth: 200)

            PreviewView(
                markdown: document.content,
                onCoordinatorReady: { driver in
                    guard let bar = findBar else { return }
                    bar.sideBySideComposite.secondary = driver
                    bar.driver = bar.sideBySideComposite
                    if bar.isVisible, !bar.query.isEmpty { bar.refreshSearch() }
                }
            )
            .frame(minWidth: 200)
        }
        .onChange(of: document.content) { _, _ in
            // Preview re-renders on content change; re-apply search so it stays highlighted.
            guard let bar = findBar, bar.isVisible, !bar.query.isEmpty else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                bar.sideBySideComposite.secondary?.applySearch(
                    query: bar.query,
                    caseSensitive: bar.caseSensitive
                ) { _ in
                    if bar.currentMatch > 0 {
                        bar.sideBySideComposite.secondary?.jumpTo(matchIndex: bar.currentMatch - 1)
                    }
                }
            }
        }
        .onDisappear {
            // Clean up so stale references don't leak into other modes.
            findBar?.sideBySideComposite.primary = nil
            findBar?.sideBySideComposite.secondary = nil
        }
    }
}
