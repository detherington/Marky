import SwiftUI

struct WYSIWYGEditorView: View {
    @Bindable var document: DocumentViewModel
    @State private var displayedContent: String = ""
    @State private var trackedDocumentID: UUID?
    @State private var formattingBridge = FormattingBridge()
    @State private var showingLinkSheet = false
    @State private var linkURL = ""

    var body: some View {
        VStack(spacing: 0) {
            FormattingToolbar(bridge: formattingBridge)
            Divider()
            MarkdownWebView(
                mode: .wysiwyg,
                markdown: displayedContent,
                onContentChange: { newMarkdown in
                    document.content = newMarkdown
                },
                onLinkRequested: {
                    linkURL = ""
                    showingLinkSheet = true
                },
                formattingBridge: formattingBridge,
                documentID: document.id
            )
        }
        .onAppear {
            loadDocument()
        }
        .onChange(of: document.id) {
            loadDocument()
        }
        .sheet(isPresented: $showingLinkSheet) {
            linkSheet
        }
    }

    private func loadDocument() {
        trackedDocumentID = document.id
        displayedContent = document.content
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
