import SwiftUI

struct FileBrowserView: View {
    let fileTree: [FileNode]
    let onFileSelected: (URL) -> Void

    var body: some View {
        List {
            ForEach(fileTree) { node in
                FileNodeRow(node: node, onFileSelected: onFileSelected)
            }
        }
        .listStyle(.sidebar)
    }
}

struct FileNodeRow: View {
    let node: FileNode
    let onFileSelected: (URL) -> Void

    var body: some View {
        if node.isDirectory {
            DisclosureGroup {
                if let children = node.children {
                    ForEach(children) { child in
                        FileNodeRow(node: child, onFileSelected: onFileSelected)
                    }
                }
            } label: {
                Label(node.name, systemImage: "folder")
                    .font(.system(size: 13))
            }
        } else {
            Button(action: { onFileSelected(node.url) }) {
                Label(node.name, systemImage: iconForFile(node))
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
        }
    }

    private func iconForFile(_ node: FileNode) -> String {
        if node.isMarkdown {
            return "doc.text"
        }
        return "doc"
    }
}
