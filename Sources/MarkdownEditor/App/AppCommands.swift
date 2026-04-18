import SwiftUI
import UniformTypeIdentifiers
import Sparkle

struct AppCommands: Commands {
    @Bindable var workspace: Workspace
    @StateObject private var updateViewModel: UpdateViewModel

    init(workspace: Workspace, updater: SPUUpdater) {
        self.workspace = workspace
        _updateViewModel = StateObject(wrappedValue: UpdateViewModel(updater: updater))
    }

    var body: some Commands {
        // "Check for Updates…" appears under the Marky app menu, above Settings/Quit.
        CommandGroup(after: .appInfo) {
            CheckForUpdatesView(viewModel: updateViewModel)
        }

        CommandGroup(replacing: .newItem) {
            Button("New") {
                workspace.newDocument()
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("Open...") {
                openFile()
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("Open Folder...") {
                openFolder()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Button("Go to File…") {
                workspace.quickSwitcher.open()
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(workspace.sidebarRootURL == nil)

            Divider()

            Button("Save") {
                saveCurrentDocument()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(workspace.activeDocument == nil)

            Button("Save As...") {
                saveCurrentDocumentAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(workspace.activeDocument == nil)

            Divider()

            Button("Close Tab") {
                if let id = workspace.activeTabID {
                    workspace.closeTab(id)
                }
            }
            .keyboardShortcut("w", modifiers: .command)
            .disabled(workspace.activeTab == nil)
        }

        // Remove the default text formatting menu (Font > Bold/Italic) that steals Cmd+B/I
        CommandGroup(replacing: .textFormatting) { }

        // Find & Replace — placed in the standard Edit menu area
        CommandGroup(after: .pasteboard) {
            Divider()

            Button("Find…") {
                workspace.findBar.open(replaceMode: false)
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("Find and Replace…") {
                workspace.findBar.open(replaceMode: true)
            }
            .keyboardShortcut("f", modifiers: [.command, .option])

            Button("Find Next") {
                workspace.findBar.jumpNext()
            }
            .keyboardShortcut("g", modifiers: .command)
            .disabled(workspace.findBar.matchCount == 0)

            Button("Find Previous") {
                workspace.findBar.jumpPrevious()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(workspace.findBar.matchCount == 0)
        }

        CommandGroup(after: .textEditing) {
            Divider()

            Picker("Editing Mode", selection: $workspace.editingMode) {
                Text("Raw Markdown").tag(EditingMode.raw)
                    .keyboardShortcut("1", modifiers: .command)
                Text("Side by Side").tag(EditingMode.sideBySide)
                    .keyboardShortcut("2", modifiers: .command)
                Text("WYSIWYG").tag(EditingMode.wysiwyg)
                    .keyboardShortcut("3", modifiers: .command)
            }
        }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK {
            for url in panel.urls {
                let doc = DocumentViewModel(fileURL: url)
                workspace.openDocument(doc)
            }
        }
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            workspace.sidebarRootURL = url
        }
    }

    private func saveCurrentDocument() {
        guard let doc = workspace.activeDocument else { return }
        if doc.fileURL != nil {
            try? doc.save()
        } else {
            saveCurrentDocumentAs()
        }
    }

    private func saveCurrentDocumentAs() {
        guard let doc = workspace.activeDocument else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = doc.displayName.hasSuffix(".md") ? doc.displayName : "Untitled.md"
        if panel.runModal() == .OK, let url = panel.url {
            try? doc.save(to: url)
        }
    }
}
