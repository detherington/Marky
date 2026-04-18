import SwiftUI

/// Read-only markdown preview using WKWebView.
struct PreviewView: View {
    let markdown: String
    /// Called once with the WebView coordinator when it's created. Used by SideBySideView
    /// to wire the coordinator into its composite find driver.
    var onCoordinatorReady: ((FindDriver) -> Void)? = nil

    var body: some View {
        MarkdownWebView(
            mode: .preview,
            markdown: markdown,
            onCoordinatorReady: { coord in
                onCoordinatorReady?(coord)
            }
        )
    }
}
