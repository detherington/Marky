import SwiftUI

struct MainWindowView: View {
    @State var workspace: Workspace
    @State private var fileBrowser = FileBrowserViewModel()

    var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 350)
        } detail: {
            VStack(spacing: 0) {
                if !workspace.tabs.isEmpty {
                    TabBarView(workspace: workspace)
                    Divider()
                }

                if let document = workspace.activeDocument {
                    EditorContainerView(
                        document: document,
                        editingMode: workspace.editingMode,
                        findBar: workspace.findBar
                    )
                } else {
                    emptyState
                }
            }
        }
        .navigationTitle(windowTitle)
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                Picker("Mode", selection: $workspace.editingMode) {
                    ForEach(EditingMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
            }
        }
        .onChange(of: workspace.sidebarRootURL) { _, newURL in
            if let url = newURL {
                fileBrowser.openFolder(url)
            }
        }
        .overlay {
            if workspace.quickSwitcher.isVisible {
                QuickSwitcherView(
                    state: workspace.quickSwitcher,
                    rootURL: fileBrowser.rootURL,
                    files: fileBrowser.allFiles
                ) { url in
                    workspace.openFile(url)
                }
                .transition(.opacity)
            }
        }
    }

    private var windowTitle: String {
        if let doc = workspace.activeDocument {
            let dirty = doc.isDirty ? " - Edited" : ""
            return doc.displayName + dirty
        }
        return "Marky"
    }

    @ViewBuilder
    private var sidebarContent: some View {
        if fileBrowser.rootURL != nil {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    if let rootName = fileBrowser.rootURL?.lastPathComponent {
                        Text(rootName)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    Spacer()
                    Menu {
                        ForEach(FileSortOrder.allCases, id: \.self) { order in
                            Button {
                                fileBrowser.sortOrder = order
                                fileBrowser.refresh()
                            } label: {
                                HStack {
                                    Text(order.rawValue)
                                    if fileBrowser.sortOrder == order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 20)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                Divider()
                FileBrowserView(fileTree: fileBrowser.fileTree) { url in
                    let doc = DocumentViewModel(fileURL: url)
                    workspace.openDocument(doc)
                }
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Open a folder to browse files")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Open Folder...") {
                    openFolderPanel()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No document open")
                .font(.title3)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("New Document") {
                    workspace.newDocument()
                }
                Button("Open File...") {
                    openFilePanel()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to browse"
        if panel.runModal() == .OK, let url = panel.url {
            workspace.sidebarRootURL = url
        }
    }

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.plainText]
        panel.message = "Choose markdown files to open"
        if panel.runModal() == .OK {
            for url in panel.urls {
                let doc = DocumentViewModel(fileURL: url)
                workspace.openDocument(doc)
            }
        }
    }
}
