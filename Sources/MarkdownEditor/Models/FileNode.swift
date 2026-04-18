import Foundation

struct FileNode: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    let name: String
    let isDirectory: Bool
    let dateModified: Date?
    let dateAccessed: Date?
    var children: [FileNode]?

    var isMarkdown: Bool {
        let ext = url.pathExtension.lowercased()
        return ["md", "markdown", "mdown", "mkd", "mkdn", "txt"].contains(ext)
    }
}

enum FileSortOrder: String, CaseIterable {
    case lastOpened = "Last Opened"
    case lastModified = "Last Modified"
    case nameAsc = "Name (A-Z)"
    case nameDesc = "Name (Z-A)"
}
