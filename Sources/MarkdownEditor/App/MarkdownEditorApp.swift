import SwiftUI
import AppKit
import Sparkle

@main
struct MarkyApp: App {
    @NSApplicationDelegateAdaptor(MarkyAppDelegate.self) var appDelegate
    @State private var workspace = Workspace.shared

    var body: some Scene {
        WindowGroup {
            MainWindowView(workspace: workspace)
                .frame(minWidth: 700, minHeight: 500)
                .background(WindowAccessor(
                    fileURL: workspace.activeDocument?.fileURL,
                    isEdited: workspace.activeDocument?.isDirty ?? false
                ))
                .onOpenURL { url in
                    workspace.openFile(url)
                }
        }
        .commands {
            AppCommands(workspace: workspace, updater: appDelegate.updaterController.updater)
        }
        .defaultSize(width: 1100, height: 750)
    }
}

class MarkyAppDelegate: NSObject, NSApplicationDelegate {
    /// Sparkle's standard controller — owns the SPUUpdater and bridges to standard UI.
    /// Initialized eagerly so AppCommands can reference the updater at startup.
    let updaterController: SPUStandardUpdaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)

        if let iconURL = AppBundle.resources.url(forResource: "AppIcon", withExtension: "icns") {
            NSApplication.shared.applicationIconImage = NSImage(contentsOf: iconURL)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            Workspace.shared.openFile(url)
        }
    }
}

/// Bridges SwiftUI to NSWindow for native title bar features (document proxy icon, edited dot)
struct WindowAccessor: NSViewRepresentable {
    let fileURL: URL?
    let isEdited: Bool

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.isDocumentEdited = isEdited
            if let url = fileURL {
                window.representedURL = url
                window.title = url.lastPathComponent
            } else {
                window.representedURL = nil
                window.title = "Marky"
            }
        }
    }
}
