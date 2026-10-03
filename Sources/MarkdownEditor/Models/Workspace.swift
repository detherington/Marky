import Foundation
import SwiftUI

enum EditingMode: String, CaseIterable {
    case raw = "Markdown"
    case sideBySide = "Split"
    case wysiwyg = "Preview"
}

/// UserDefaults key for the default editing mode used when the app launches.
let defaultEditingModeKey = "defaultEditingMode"

@Observable
final class Workspace {
    static let shared = Workspace()

    var tabs: [Tab] = []
    var activeTabID: UUID?
    var sidebarRootURL: URL?
    var editingMode: EditingMode
    var isSidebarVisible: Bool = true
    /// Shared state for Find & Replace — persists across tab switches so the query sticks.
    let findBar = FindBarState()
    /// Shared state for the Cmd+P quick file switcher palette.
    let quickSwitcher = QuickSwitcherState()

    init() {
        // Load the user's preferred default editing mode (set in Settings), falling
        // back to Markdown.
        let saved = UserDefaults.standard.string(forKey: defaultEditingModeKey)
        self.editingMode = saved.flatMap(EditingMode.init(rawValue:)) ?? .raw
    }

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
