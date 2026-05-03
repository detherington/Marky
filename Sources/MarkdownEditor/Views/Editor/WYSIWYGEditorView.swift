import SwiftUI

struct WYSIWYGEditorView: View {
    @Bindable var document: DocumentViewModel
    var findBar: FindBarState? = nil
    @State private var formattingBridge = FormattingBridge()
    @State private var showingLinkSheet = false
    @State private var linkURL = ""

    var body: some View {
        VStack(spacing: 0) {
            FormattingToolbar(bridge: formattingBridge)
            Divider()
            // Pass document.content directly. MarkdownWebView gates re-pushes via
            // `hasDeliveredInitialContent` so keystroke updates don't reload the editor;
            // tab switches force a reload via documentID change. Using an intermediate
            // @State snapshot caused stale content to be loaded on tab switch because
            // body re-evaluation outraced onChange(of:document.id).
            MarkdownWebView(
                mode: .wysiwyg,
                markdown: document.content,
                onContentChange: { newMarkdown in
                    document.content = newMarkdown
                },
                onLinkRequested: {
                    linkURL = ""
                    showingLinkSheet = true
                },
                formattingBridge: formattingBridge,
                findBar: findBar,
                documentID: document.id
            )
        }
        .sheet(isPresented: $showingLinkSheet) {
            linkSheet
        }
    }

    private var linkSheet: some View {
        VStack(spacing: 16) {
            Text("Insert Link")
                .font(.headline)

            TextField("URL", text: $linkURL)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    showingLinkSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Insert") {
                    let url = linkURL.isEmpty ? "https://" : linkURL
                    formattingBridge.insertLink(url: url, text: url)
                    showingLinkSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(linkURL.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
