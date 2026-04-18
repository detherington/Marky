import SwiftUI
import Sparkle

/// SwiftUI wrapper for Sparkle's updater that exposes a bindable "can check for updates" state.
/// Sparkle disables the menu item automatically while a check is in progress.
final class UpdateViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}

/// The SwiftUI view that renders as the "Check for Updates…" menu button.
struct CheckForUpdatesView: View {
    @ObservedObject var viewModel: UpdateViewModel

    var body: some View {
        Button("Check for Updates…", action: viewModel.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}
