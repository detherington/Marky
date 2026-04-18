import Foundation
import AppKit

@Observable
final class DocumentViewModel: Identifiable {
    let id = UUID()
    var content: String = ""
    var fileURL: URL?
    var encoding: String.Encoding = .utf8

    private var lastSavedContent: String = ""

    var isDirty: Bool {
        content != lastSavedContent
    }

    var displayName: String {
        fileURL?.lastPathComponent ?? "Untitled"
    }

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL
        if let url = fileURL {
            load(from: url)
        }
    }

    func load(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? ""
            lastSavedContent = content
            fileURL = url
        } catch {
            print("Failed to load \(url.path): \(error)")
        }
    }

    func save() throws {
        guard let url = fileURL else {
            throw NSError(domain: "Marky", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No file URL set"])
        }
        try save(to: url)
    }

    func save(to url: URL) throws {
        guard let data = content.data(using: encoding) else {
            throw NSError(domain: "Marky", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to encode content"])
        }
        try data.write(to: url, options: .atomic)
        fileURL = url
        lastSavedContent = content
    }

    func markClean() {
        lastSavedContent = content
    }
}
