import SwiftUI

/// Tweede tab: beheer van eigen radiozenders + favorieten export/import + recents wissen.
struct StationsSettingsView: View {
    @Environment(PlayerViewModel.self) private var player

    @State private var showAddSheet: Bool = false
    @State private var editingStation: DataStore.UserCustomStation?
    @State private var showImportConfirm: Bool = false
    @State private var importedPayload: FavoritesExporter.ExportPayload?
    @State private var importError: String?
    @State private var exportSuccess: Bool = false
    @State private var showClearRecentsConfirm: Bool = false

    var body: some View {
        Form {
            Section {
                if player.dataStore.customStations.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "Nog geen eigen zenders"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text(String(localized: "Voeg een eigen stream-URL toe om hem in de drawer en preset-slots beschikbaar te maken."))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(player.dataStore.customStations) { station in
                        HStack(spacing: 10) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(station.name)
                                    .font(.system(size: 12, weight: .medium))
                                Text(station.streamURL.absoluteString)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Button {
                                editingStation = station
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                            .help(String(localized: "Bewerk"))

                            Button(role: .destructive) {
                                player.dataStore.removeCustomStation(id: station.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help(String(localized: "Verwijder"))
                        }
                        .padding(.vertical, 2)
                    }
                }

                Button {
                    showAddSheet = true
                } label: {
                    Label(String(localized: "Eigen zender toevoegen"), systemImage: "plus.circle")
                }
            } header: {
                Text(String(localized: "Eigen zenders"))
            }

            Section {
                HStack {
                    Button {
                        exportFavorites()
                    } label: {
                        Label(String(localized: "Exporteer favorieten en eigen zenders..."), systemImage: "square.and.arrow.up")
                    }
                    if exportSuccess {
                        Text(String(localized: "Geexporteerd"))
                            .font(.caption)
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                }

                Button {
                    importFavorites()
                } label: {
                    Label(String(localized: "Importeer favorieten..."), systemImage: "square.and.arrow.down")
                }

                if let importError {
                    Text(importError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text(String(localized: "Favorieten"))
            } footer: {
                Text(String(localized: "Exporteert favorieten-slots en eigen zenders als JSON. Importeren biedt de keuze tussen samenvoegen of vervangen."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(role: .destructive) {
                    showClearRecentsConfirm = true
                } label: {
                    Label(String(localized: "Wis recent geluisterd"), systemImage: "trash")
                }
            } header: {
                Text(String(localized: "Recent geluisterd"))
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showAddSheet) {
            CustomStationFormView(
                mode: .add,
                onSubmit: { name, url, logoURL in
                    let station = DataStore.UserCustomStation(name: name, streamURL: url, logoURL: logoURL)
                    player.dataStore.addCustomStation(station)
                }
            )
        }
        .sheet(item: $editingStation) { station in
            CustomStationFormView(
                mode: .edit(existing: station),
                onSubmit: { name, url, logoURL in
                    player.dataStore.removeCustomStation(id: station.id)
                    let updated = DataStore.UserCustomStation(name: name, streamURL: url, logoURL: logoURL)
                    player.dataStore.addCustomStation(updated)
                }
            )
        }
        .confirmationDialog(
            String(localized: "Bestaand favorieten-bestand gedetecteerd"),
            isPresented: $showImportConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Samenvoegen")) {
                if let payload = importedPayload {
                    FavoritesExporter.apply(payload, to: player.dataStore, strategy: .merge)
                    importedPayload = nil
                }
            }
            Button(String(localized: "Vervangen"), role: .destructive) {
                if let payload = importedPayload {
                    FavoritesExporter.apply(payload, to: player.dataStore, strategy: .replace)
                    importedPayload = nil
                }
            }
            Button(String(localized: "Annuleer"), role: .cancel) {
                importedPayload = nil
            }
        }
        .confirmationDialog(
            String(localized: "Recent geluisterd wissen?"),
            isPresented: $showClearRecentsConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Wis"), role: .destructive) {
                player.dataStore.clearRecents()
            }
            Button(String(localized: "Annuleer"), role: .cancel) {}
        }
    }

    // MARK: - Export / Import handlers

    private func exportFavorites() {
        Task {
            let payload = FavoritesExporter.payload(from: player.dataStore)
            let url = await FavoritesExporter.runSavePanel(suggestedFilename: "radio-naoufal-favorites.json")
            guard let url else { return }
            do {
                try FavoritesExporter.write(payload, to: url)
                await MainActor.run {
                    exportSuccess = true
                }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run {
                    exportSuccess = false
                }
            } catch {
                await MainActor.run {
                    importError = error.localizedDescription
                }
            }
        }
    }

    private func importFavorites() {
        Task {
            let url = await FavoritesExporter.runOpenPanel()
            guard let url else { return }
            do {
                let payload = try FavoritesExporter.read(from: url)
                await MainActor.run {
                    importedPayload = payload
                    showImportConfirm = true
                    importError = nil
                }
            } catch {
                await MainActor.run {
                    importError = error.localizedDescription
                }
            }
        }
    }
}
