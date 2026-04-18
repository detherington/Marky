import Foundation

/// Safe resource bundle resolver that works both for `swift run` and `.app` bundles.
/// The auto-generated Bundle.module fatalErrors if it can't find the bundle,
/// which fails inside .app bundles on other machines because the hardcoded
/// build path doesn't exist. This resolver checks additional paths.
enum AppBundle {
    static let resources: Bundle = {
        let bundleName = "Marky_Marky"

        let candidates = [
            // .app bundle: Contents/Resources/
            Bundle.main.resourceURL,
            // Next to the executable (swift run)
            Bundle.main.bundleURL,
            // Next to this code's binary
            Bundle(for: _BundleAnchor.self).bundleURL,
            Bundle(for: _BundleAnchor.self).resourceURL,
        ]

        for candidate in candidates {
            guard let candidate = candidate else { continue }
            let bundlePath = candidate.appendingPathComponent(bundleName + ".bundle")
            if let bundle = Bundle(path: bundlePath.path) {
                return bundle
            }
        }

        // Last resort: try Bundle.module (may fatalError)
        return Bundle.module
    }()
}

private class _BundleAnchor {}
