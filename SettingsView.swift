import SwiftUI
import Photos

/// Settings sheet — ad toggle + album picker.
/// Receives the ViewModel so it can read/write the selected album directly.
struct SettingsView: View {
    let viewModel: SvenSwipeViewModel

    /// Local mirror of the persisted value so the Toggle animates properly.
    @State private var adsEnabled: Bool

    init(viewModel: SvenSwipeViewModel) {
        self.viewModel = viewModel
        self._adsEnabled = State(initialValue: AdSettings.shared.adsEnabled)
    }

    var body: some View {
        List {
            // MARK: Album
            Section {
                // "Alle Fotos" resets to the full library
                Button {
                    viewModel.selectAlbum(nil)
                } label: {
                    HStack {
                        Text("Alle Fotos")
                            .foregroundStyle(.primary)
                        Spacer()
                        if viewModel.selectedAlbum == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                ForEach(viewModel.albums, id: \.collection.localIdentifier) { album in
                    Button {
                        viewModel.selectAlbum(album)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(album.title)
                                    .foregroundStyle(.primary)
                                Text("\(album.count) Foto\(album.count == 1 ? "" : "s")")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if viewModel.selectedAlbum?.collection.localIdentifier == album.collection.localIdentifier {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            } header: {
                Text("Album")
            }

            // MARK: Werbung
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

