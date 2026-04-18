import SwiftUI

/// Floating Cmd+P palette. Overlaid in MainWindowView when `state.isVisible` is true.
struct QuickSwitcherView: View {
    @Bindable var state: QuickSwitcherState
    var rootURL: URL?
    var files: [FileNode]
    var onOpen: (URL) -> Void

    @FocusState private var focused: Bool
    // Local mirror of results so the ScrollView updates when we recompute.
    @State private var resultsSnapshot: [FileNode] = []
    @State private var selectedSnapshot: Int = 0

    var body: some View {
        ZStack(alignment: .top) {
            // Scrim — click anywhere outside to close
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { state.close() }

            palette
                .frame(width: 560)
                .padding(.top, 80)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .onChange(of: state.requestFocusToken) { _, _ in grabFocus() }
        .onAppear {
            grabFocus()
            recompute()
        }
    }

    private var palette: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                TextField("Go to File", text: $state.query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($focused)
                    .onSubmit(openSelected)
                    .onKeyPress(.upArrow) {
                        state.selectPrevious()
                        selectedSnapshot = state.selectedIndex
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        state.selectNext()
                        selectedSnapshot = state.selectedIndex
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        state.close()
                        return .handled
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            // Results
            if rootURL == nil {
                emptyHint("Open a folder first", icon: "folder.badge.questionmark")
            } else if resultsSnapshot.isEmpty {
                if state.query.trimmingCharacters(in: .whitespaces).isEmpty {
                    emptyHint("No files in this folder", icon: "doc.text")
                } else {
                    emptyHint("No matches", icon: "questionmark.circle")
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(resultsSnapshot.enumerated()), id: \.element.id) { index, file in
                                row(file: file, index: index)
                                    .id(file.id)
                            }
                        }
                    }
                    .frame(maxHeight: 360)
                    .onChange(of: selectedSnapshot) { _, newIndex in
                        guard newIndex >= 0, newIndex < resultsSnapshot.count else { return }
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(resultsSnapshot[newIndex].id, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 24, y: 8)
        .onChange(of: state.query) { _, _ in
            recompute()
        }
    }

    @ViewBuilder
    private func row(file: FileNode, index: Int) -> some View {
        let isSelected = index == selectedSnapshot
        let relativePath = relativePath(for: file)

        HStack(spacing: 10) {
            Image(systemName: file.isMarkdown ? "doc.text" : "doc")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                if !relativePath.isEmpty {
                    Text(relativePath)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            state.selectedIndex = index
            openSelected()
        }
    }

    private func emptyHint(_ text: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    private func relativePath(for file: FileNode) -> String {
        guard let root = rootURL else { return "" }
        let rootPath = root.path
        let filePath = file.url.deletingLastPathComponent().path
        guard filePath.hasPrefix(rootPath) else { return filePath }
        let rel = String(filePath.dropFirst(rootPath.count))
        return rel.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func openSelected() {
        guard let file = state.selectedFile else { return }
        onOpen(file.url)
        state.close()
    }

    private func recompute() {
        state.recomputeResults(from: files, rootURL: rootURL)
        resultsSnapshot = state.results
        selectedSnapshot = state.selectedIndex
    }

    private func grabFocus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApplication.shared.keyWindow?.makeFirstResponder(nil)
            focused = true
        }
    }
}
