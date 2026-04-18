import SwiftUI

/// Unified Find & Replace bar, layered above the active editor by EditorContainerView.
/// Drives FindBarState; the state in turn talks to the active FindDriver.
struct FindBarView: View {
    @Bindable var state: FindBarState
    @FocusState private var focus: Field?

    enum Field { case find, replace }

    var body: some View {
        VStack(spacing: 4) {
            findRow
            if state.isReplaceMode {
                replaceRow
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
        .onAppear {
            grabFocus()
            state.refreshSearch()
        }
        .onChange(of: state.query) { _, _ in state.refreshSearch() }
        .onChange(of: state.caseSensitive) { _, _ in state.refreshSearch() }
        .onChange(of: state.requestFocusToken) { _, _ in
            grabFocus()
        }
    }

    /// Aggressively move focus to the find field. SwiftUI's @FocusState by itself loses
    /// the race against the existing first responder (NSTextView / WKWebView) when the
    /// bar opens, so we first drop whatever's focused at the AppKit level, then set.
    private func grabFocus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApplication.shared.keyWindow?.makeFirstResponder(nil)
            focus = .find
        }
    }

    // MARK: - Find row

    private var findRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))

            TextField("Find", text: $state.query)
                .textFieldStyle(.roundedBorder)
                .focused($focus, equals: .find)
                .onSubmit { state.jumpNext() }
                .onKeyPress(.escape) {
                    state.close()
                    return .handled
                }
                .frame(minWidth: 180)

            // Match counter
            Text(matchCountText)
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 54, alignment: .trailing)

            // Case-sensitivity toggle
            Button {
                state.caseSensitive.toggle()
            } label: {
                Text("Aa")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 24, height: 20)
                    .background(state.caseSensitive ? Color.accentColor.opacity(0.3) : Color.clear)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .help("Match case")

            // Prev / Next
            Button(action: state.jumpPrevious) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 20)
            }
            .buttonStyle(.plain)
            .disabled(state.matchCount == 0)
            .help("Previous match (⇧⌘G)")

            Button(action: state.jumpNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 20)
            }
            .buttonStyle(.plain)
            .disabled(state.matchCount == 0)
            .help("Next match (⌘G)")

            // Toggle replace row
            Button {
                state.isReplaceMode.toggle()
                if state.isReplaceMode {
                    DispatchQueue.main.async { focus = .replace }
                } else {
                    focus = .find
                }
            } label: {
                Image(systemName: state.isReplaceMode ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 20)
            }
            .buttonStyle(.plain)
            .help(state.isReplaceMode ? "Hide replace" : "Show replace")

            // Close
            Button {
                state.close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 20)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .help("Close find bar (esc)")
        }
    }

    // MARK: - Replace row

    private var replaceRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.turn.down.right")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
                .frame(width: 16)

            TextField("Replace", text: $state.replacement)
                .textFieldStyle(.roundedBorder)
                .focused($focus, equals: .replace)
                .onSubmit { state.replaceCurrent() }
                .onKeyPress(.escape) {
                    state.close()
                    return .handled
                }
                .frame(minWidth: 180)

            Spacer(minLength: 0)

            Button("Replace") {
                state.replaceCurrent()
            }
            .disabled(state.matchCount == 0 || state.query.isEmpty)

            Button("Replace All") {
                state.replaceAll()
            }
            .disabled(state.matchCount == 0 || state.query.isEmpty)
        }
    }

    // MARK: - Helpers

    private var matchCountText: String {
        if state.query.isEmpty { return "" }
        if state.matchCount == 0 { return "No results" }
        return "\(state.currentMatch) of \(state.matchCount)"
    }
}
