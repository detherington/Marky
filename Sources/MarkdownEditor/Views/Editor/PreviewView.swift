import SwiftUI

struct PreviewView: View {
    let markdown: String

    var body: some View {
        MarkdownWebView(mode: .preview, markdown: markdown)
    }
}
