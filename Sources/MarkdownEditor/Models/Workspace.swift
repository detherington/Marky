import Foundation
import SwiftUI

enum EditingMode: String, CaseIterable {
    case raw = "Markdown"
    case sideBySide = "Split"
    case wysiwyg = "Preview"
}

@Observable
final class Workspace {
    static let shared = Workspace()

    var tabs: [Tab] = []
    var activeTabID: UUID?
    var sidebarRootURL: URL?
    var editingMode: EditingMode = .raw
    var isSidebarVisible: Bool = true

    var activeTab: Tab? {
        tabs.first { $0.id == activeTabID }
    }

    var activeDocument: DocumentViewModel? {
        activeTab?.document
    }

    func openDocument(_ document: DocumentViewModel) {
        if let existing = tabs.first(where: { $0.document.fileURL == document.fileURL && document.fileURL != nil }) {
            activeTabID = existing.id
        } else {
            let tab = Tab(document: document)
            tabs.append(tab)
            activeTabID = tab.id
        }
    }

    func closeTab(_ tabID: UUID) {
        tabs.removeAll { $0.id == tabID }
        if activeTabID == tabID {
            activeTabID = tabs.last?.id
        }
    }

    func newDocument() {
        let doc = DocumentViewModel()
        openDocument(doc)
    }

    func openFile(_ url: URL) {
        let doc = DocumentViewModel(fileURL: url)
        openDocument(doc)
    }
}
