import SwiftUI

/// Modal-form voor het toevoegen of bewerken van een eigen radiozender.
struct CustomStationFormView: View {
    enum Mode {
        case add
        case edit(existing: DataStore.UserCustomStation)
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let onSubmit: (String, URL, URL?) -> Void

    @State private var name: String = ""
    @State private var streamURLString: String = ""
    @State private var logoURLString: String = ""

    private var isAddMode: Bool {
        if case .add = mode { return true }
        return false
    }

    private var titleText: String {
        isAddMode ? String(localized: "Eigen zender toevoegen") : String(localized: "Eigen zender bewerken")
    }

    private var submitText: String {
        isAddMode ? String(localized: "Toevoegen") : String(localized: "Opslaan")
    }

    private var streamURL: URL? {
        let trimmed = streamURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    private var logoURL: URL? {
        let trimmed = logoURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && streamURL != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(titleText)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 8)

            Form {
                Section {
                    TextField(String(localized: "Naam"), text: $name, prompt: Text(String(localized: "Bijv. Mijn lokale zender")))
                    TextField(String(localized: "Stream-URL"), text: $streamURLString, prompt: Text(verbatim: "https://stream.example.com/audio.mp3"))
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                    if !streamURLString.isEmpty && streamURL == nil {
                        Label(String(localized: "URL moet beginnen met http:// of https://"), systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text(String(localized: "Verplicht"))
                }

                Section {
                    TextField(String(localized: "Logo-URL (optioneel)"), text: $logoURLString, prompt: Text(verbatim: "https://example.com/logo.png"))
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                } header: {
                    Text(String(localized: "Optioneel"))
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            HStack {
                Spacer()
                Button(String(localized: "Annuleer"), role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(submitText) {
                    guard let url = streamURL else { return }
                    onSubmit(name.trimmingCharacters(in: .whitespacesAndNewlines), url, logoURL)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .frame(width: 480)
        .onAppear {
            if case .edit(let existing) = mode {
                name = existing.name
                streamURLString = existing.streamURL.absoluteString
                logoURLString = existing.logoURL?.absoluteString ?? ""
            }
        }
    }
}
