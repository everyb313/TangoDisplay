import SwiftUI
import TangoDisplayCore

/// Setlist's "Edit Tags…": rewrites the track's tags in the file itself (via TagEditor),
/// then re-reads the row so the setlist and the live display pick the change up.
/// Unlike Edit Upcoming Info, nothing here is a local override.
struct TagEditorSheet: View {
    let entry: SetlistEntry
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var values: [String: String] = [:]
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var saved = false   // a Music-side warning still closes the sheet

    /// TagLib property name → label, in display order.
    private static let fields: [(key: String, label: String)] = [
        ("TITLE", "Title"), ("ARTIST", "Artist"), ("GENRE", "Genre"), ("DATE", "Year"),
        ("GROUPING", "Grouping"), ("ALBUMARTIST", "Album Artist"), ("COMMENT", "Comment"),
    ]

    private var original: [String: String] {
        let t = entry.track
        return ["TITLE": t.title, "ARTIST": t.artist, "GENRE": t.genre,
                "DATE": t.year.map(String.init) ?? "", "GROUPING": t.grouping ?? "",
                "ALBUMARTIST": t.albumArtist ?? "", "COMMENT": t.comment ?? ""]
    }

    private var changes: [String: String] {
        values.mapValues { $0.trimmingCharacters(in: .whitespaces) }
            .filter { original[$0.key] != $0.value }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Tags")
                .font(.headline)

            Text("Writes to \(entry.fileURL.lastPathComponent). A blank field removes that tag.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(Self.fields, id: \.key) { field in
                    GridRow {
                        Text(field.label)
                        TextField(field.label, text: binding(field.key))
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            HStack {
                if saving { ProgressView().controlSize(.small) }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(saving || changes.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .onAppear { values = original }
        .alert("Edit Tags", isPresented: Binding(get: { errorMessage != nil },
                                                 set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil; if saved { dismiss() } }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })
    }

    private func save() {
        let changes = self.changes
        saving = true
        Task { @MainActor in
            defer { saving = false }
            let warning: String?
            do {
                warning = try await TagEditor.apply(changes, to: entry)
            } catch {
                errorMessage = error.localizedDescription   // file untouched; edits stay in the sheet
                return
            }
            saved = true
            await appState.setlist.reloadMetadata(id: entry.id, force: true)
            // Display picks up the new tags if this is the current track or the next one
            // (a cortina's "Coming Up"). A genre edit can flip cortina status here too.
            appState.localPlayer?.refreshReports()
            if let warning { errorMessage = warning } else { dismiss() }
        }
    }
}
