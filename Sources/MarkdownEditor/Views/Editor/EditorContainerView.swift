import SwiftUI
import AppKit

struct EditorContainerView: View {
    @Bindable var document: DocumentViewModel
    var editingMode: EditingMode

    var body: some View {
        Group {
            switch editingMode {
            case .raw:
                RawEditorView(text: $document.content)
            case .sideBySide:
                SideBySideView(document: document)
            case .wysiwyg:
                WYSIWYGEditorView(document: document)
            }
        }
        .onChange(of: editingMode) {
            // Clear the window's undo manager when switching modes to prevent
            // stale undo actions from referencing deallocated editor views
            NSApplication.shared.keyWindow?.undoManager?.removeAllActions()
        }
    }
}
