import SwiftUI

/// A simple settings sheet with an ad-toggle.
/// Reads / writes through AdSettings.shared and pushes a local @State so
/// the Toggle reflects changes instantly while the sheet is open.
struct SettingsView: View {
    /// Local mirror of the persisted value so the Toggle animates properly.
    @State private var adsEnabled: Bool

    init() {
        self._adsEnabled = State(initialValue: AdSettings.shared.adsEnabled)
    }

    var body: some View {
        List {
            Section {
                Toggle("Werbung anzeigen", isOn: $adsEnabled)
                    .onChange(of: adsEnabled) { _, newValue in
                        AdSettings.shared.adsEnabled = newValue
                    }
            } header: {
                Text("Werbung")
            } footer: {
                Text("Wenn aktiviert, wird ein Banner am unteren Bildschirmrand angezeigt.")
            }
        }
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
    }
}

