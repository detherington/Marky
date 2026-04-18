import SwiftUI

struct SideBySideView: View {
    @Bindable var document: DocumentViewModel

    var body: some View {
        HSplitView {
            RawEditorView(text: $document.content)
                .frame(minWidth: 200)
            PreviewView(markdown: document.content)
                .frame(minWidth: 200)
        }
    }
}
