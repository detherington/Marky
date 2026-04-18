import SwiftUI
import AppKit

struct EditorContainerView: View {
    @Bindable var document: DocumentViewModel
    var editingMode: EditingMode
    /// Workspace-owned find bar state; pulled up so menu shortcuts can toggle it.
    @Bindable var findBar: FindBarState

    var body: some View {
        VStack(spacing: 0) {
            if findBar.isVisible {
                FindBarView(state: findBar)
                Divider()
            }

            Group {
                switch editingMode {
                case .raw:
                    RawEditorView(text: $document.content, findBar: findBar)
                case .sideBySide:
                    SideBySideView(document: document, findBar: findBar)
                case .wysiwyg:
                    WYSIWYGEditorView(document: document, findBar: findBar)
                }
            }
        }
        .onChange(of: editingMode) {
            // Clear the window's undo manager when switching modes to prevent
            // stale undo actions from referencing deallocated editor views
            NSApplication.shared.keyWindow?.undoManager?.removeAllActions()
            // Clear find highlights on the outgoing driver; new driver re-registers.
            findBar.driver?.clearSearch()
            findBar.driver = nil
        }
        .onChange(of: document.id) {
            // Tab switch — re-search on the new doc.
            if findBar.isVisible, !findBar.query.isEmpty {
                DispatchQueue.main.async {
                    findBar.refreshSearch()
                }
            }
        }
    }
}
