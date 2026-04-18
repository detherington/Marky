import Foundation

struct Tab: Identifiable {
    let id = UUID()
    let document: DocumentViewModel

    var title: String {
        if let url = document.fileURL {
            return url.lastPathComponent
        }
        return "Untitled"
    }

    var isDirty: Bool {
        document.isDirty
    }
}
