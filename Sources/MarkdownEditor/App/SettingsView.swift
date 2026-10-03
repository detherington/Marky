import SwiftUI

/// Marky's Settings/Preferences window. Opened via the standard Marky → Settings…
/// menu item (Cmd+,) or from the app menu.
struct SettingsView: View {
    @AppStorage(defaultEditingModeKey) private var defaultModeRaw: String = EditingMode.raw.rawValue

    var body: some View {
        Form {
            Section {
                Picker("Open new windows in:", selection: $defaultModeRaw) {
                    ForEach(EditingMode.allCases, id: \.rawValue) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.inline)
                Text("Takes effect the next time you launch Marky.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } header: {
                Text("Default view")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 220)
    }
}
