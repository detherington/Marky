import Foundation

@Observable
final class FileBrowserViewModel {
    var rootURL: URL?
    var fileTree: [FileNode] = []
    var sortOrder: FileSortOrder = .lastOpened

    private var fileWatcher: FileWatcher?

    func openFolder(_ url: URL) {
        rootURL = url
        refresh()
        startWatching()
    }

    func refresh() {
        guard let rootURL = rootURL else {
            fileTree = []
            return
        }
        fileTree = scanDirectory(rootURL)
    }

    private func scanDirectory(_ url: URL) -> [FileNode] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey, .contentAccessDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents
            .map { itemURL -> FileNode in
                let values = try? itemURL.resourceValues(forKeys: [
                    .isDirectoryKey, .contentModificationDateKey, .contentAccessDateKey
                ])
                let isDir = values?.isDirectory ?? false
                return FileNode(
                    url: itemURL,
                    name: itemURL.lastPathComponent,
                    isDirectory: isDir,
                    dateModified: values?.contentModificationDate,
                    dateAccessed: values?.contentAccessDate,
                    children: isDir ? scanDirectory(itemURL) : nil
                )
            }
            .sorted { a, b in
                // Folders always come first
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                return compareNodes(a, b)
            }
    }

    private func compareNodes(_ a: FileNode, _ b: FileNode) -> Bool {
        switch sortOrder {
        case .lastOpened:
            let aDate = a.dateAccessed ?? .distantPast
            let bDate = b.dateAccessed ?? .distantPast
            return aDate > bDate
        case .lastModified:
            let aDate = a.dateModified ?? .distantPast
            let bDate = b.dateModified ?? .distantPast
            return aDate > bDate
        case .nameAsc:
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        case .nameDesc:
            return a.name.localizedStandardCompare(b.name) == .orderedDescending
        }
    }

    private func startWatching() {
        fileWatcher?.stop()
        guard let rootURL = rootURL else { return }
        fileWatcher = FileWatcher(url: rootURL) { [weak self] in
            DispatchQueue.main.async {
                self?.refresh()
            }
        }
        fileWatcher?.start()
    }
}
