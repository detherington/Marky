import SwiftUI

struct FormattingToolbar: View {
    let bridge: FormattingBridge
    @State private var showingLinkSheet = false
    @State private var linkURL = ""

    var body: some View {
        HStack(spacing: 2) {
            Group {
                toolbarButton("bold", icon: "bold", tooltip: "Bold (Cmd+B)") {
                    bridge.bold()
                }
                toolbarButton("italic", icon: "italic", tooltip: "Italic (Cmd+I)") {
                    bridge.italic()
                }
                toolbarButton("strikethrough", icon: "strikethrough", tooltip: "Strikethrough") {
                    bridge.strikethrough()
                }
                toolbarButton("code", icon: "chevron.left.forwardslash.chevron.right", tooltip: "Inline Code") {
                    bridge.code()
                }
            }

            Divider().frame(height: 18).padding(.horizontal, 4)

            Group {
                headingMenu
                toolbarButton("quote", icon: "text.quote", tooltip: "Blockquote") {
                    bridge.blockquote()
                }
            }

            Divider().frame(height: 18).padding(.horizontal, 4)

            Group {
                toolbarButton("ul", icon: "list.bullet", tooltip: "Bulleted List") {
                    bridge.unorderedList()
                }
                toolbarButton("ol", icon: "list.number", tooltip: "Numbered List") {
                    bridge.orderedList()
                }
            }

            Divider().frame(height: 18).padding(.horizontal, 4)

            toolbarButton("link", icon: "link", tooltip: "Insert Link (Cmd+K)") {
                linkURL = ""
                showingLinkSheet = true
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
        .sheet(isPresented: $showingLinkSheet) {
            linkSheet
        }
    }

    private func toolbarButton(_ id: String, icon: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .contentShape(Rectangle())
    }

    private var headingMenu: some View {
        Menu {
            Button("Heading 1") { bridge.heading(1) }
            Button("Heading 2") { bridge.heading(2) }
            Button("Heading 3") { bridge.heading(3) }
            Button("Heading 4") { bridge.heading(4) }
            Divider()
            Button("Paragraph") { bridge.paragraph() }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 13))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .frame(height: 24)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 40)
        .help("Heading Level")
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
                    bridge.insertLink(url: url, text: url)
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
