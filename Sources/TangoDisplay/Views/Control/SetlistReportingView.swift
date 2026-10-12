import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SetlistReportingView: View {
    @EnvironmentObject var reportStore: SetlistReportStore
    @EnvironmentObject var settings: AppSettings

    @State private var selectedIDs: Set<UUID> = []
    @State private var pendingDelete: SetlistReportMetadata? = nil
    @State private var showDeleteConfirmation = false
    @State private var showBulkDeleteConfirmation = false
    @State private var errorMessage: String? = nil
    @State private var showError = false
    @State private var renaming: SetlistReportMetadata? = nil
    @State private var renameText = ""

    private var selectedCount: Int { selectedIDs.count }

    private var totalSelectedTracks: Int {
        reportStore.reports
            .filter { selectedIDs.contains($0.id) }
            .reduce(0) { $0 + $1.trackCount }
    }

    private var allSelected: Bool {
        !reportStore.reports.isEmpty &&
        reportStore.reports.allSatisfy { selectedIDs.contains($0.id) }
    }

    private var someSelected: Bool { !selectedIDs.isEmpty && !allSelected }

    var body: some View {
        VStack(spacing: 0) {
            if reportStore.reports.isEmpty {
                emptyState
            } else {
                infoBanner
                Divider()
                selectionControlRow
                Divider()
                reportListContent
                Divider()
                bottomSummaryBar
            }
        }
        .navigationTitle("Reports")
        .confirmationDialog(
            "Delete \"\(pendingDelete?.name ?? "")\"?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let item = pendingDelete {
                    try? reportStore.delete(item)
                    selectedIDs.remove(item.id)
                    pendingDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("This setlist export will be permanently removed.")
        }
        .confirmationDialog(
            "Delete \(selectedCount) report\(selectedCount == 1 ? "" : "s")?",
            isPresented: $showBulkDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete \(selectedCount) report\(selectedCount == 1 ? "" : "s")", role: .destructive) {
                deleteSelected()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The selected setlist exports will be permanently removed.")
        }
        .alert("Rename Report", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            TextField("Report name", text: $renameText)
            Button("Rename") {
                let name = renameText.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty, let item = renaming else { return }
                renaming = nil
                do {
                    try reportStore.rename(item, to: name)
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        .alert("Report Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Info banner

    private var infoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
                .font(.system(size: 15))

            VStack(alignment: .leading, spacing: 2) {
                Text("Select one or more reports to generate")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Text("Selected reports will be combined into a single report")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if selectedCount > 0 {
                Button(action: { showBulkDeleteConfirmation = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "trash")
                        Text("Delete (\(selectedCount))")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Delete the selected setlist exports")
            }

            Button(action: generateReport) {
                HStack(spacing: 5) {
                    Image(systemName: "doc.text.fill")
                    Text(selectedCount == 0 ? "Generate Report" : "Generate Report (\(selectedCount))")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(selectedCount == 0)
            .help("Generate an HTML report for the selected setlists")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.08, green: 0.10, blue: 0.22))
        .overlay(
            Rectangle()
                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Selection control row

    private var selectionControlRow: some View {
        HStack(spacing: 8) {
            Button(action: toggleSelectAll) {
                checkboxView(state: allSelected ? .checked : (someSelected ? .partial : .unchecked))
            }
            .buttonStyle(.plain)

            Text(selectedCount == 0 ? "None selected" : "\(selectedCount) selected")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Spacer()

            Button("Select all") {
                selectedIDs = Set(reportStore.reports.map { $0.id })
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.blue)

            Text("|")
                .font(.system(size: 12))
                .foregroundColor(Color.secondary.opacity(0.5))

            Button("Clear all") {
                selectedIDs = []
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    // MARK: - Report list

    private var reportListContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(reportStore.reports) { metadata in
                    reportRow(metadata)
                    if metadata.id != reportStore.reports.last?.id {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
        }
    }

    private func reportRow(_ metadata: SetlistReportMetadata) -> some View {
        let isSelected = selectedIDs.contains(metadata.id)
        return HStack(spacing: 12) {
            checkboxView(state: isSelected ? .checked : .unchecked)

            Image(systemName: "doc.text")
                .font(.system(size: 17))
                .foregroundColor(isSelected ? .blue : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(metadata.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                HStack(spacing: 5) {
                    Text(metadata.exportDate, style: .date)
                    Text("·")
                    Text("\(metadata.trackCount) track\(metadata.trackCount == 1 ? "" : "s")")
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(metadata.trackCount) tracks")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())

            Button {
                renameText = metadata.name
                renaming = metadata
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Rename this setlist export")
            .padding(.leading, 4)

            Button {
                pendingDelete = metadata
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete this setlist export")
            .padding(.leading, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(isSelected ? Color.blue.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { toggleSelection(metadata.id) }
    }

    // MARK: - Bottom summary bar

    private var bottomSummaryBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            if selectedCount == 0 {
                Text("No reports selected")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                Text("\(selectedCount) report\(selectedCount == 1 ? "" : "s") selected · Total: \(totalSelectedTracks) tracks")
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
            }

            Spacer()

            if selectedCount > 1 {
                Text("Selected reports will be combined into a single report")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))
    }

    // MARK: - Checkbox

    private enum CheckboxState { case checked, unchecked, partial }

    @ViewBuilder
    private func checkboxView(state: CheckboxState) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    state == .unchecked ? Color.secondary.opacity(0.45) : Color.blue,
                    lineWidth: 1.5
                )
                .frame(width: 18, height: 18)

            if state == .checked {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue)
                    .frame(width: 18, height: 18)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            } else if state == .partial {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue.opacity(0.25))
                    .frame(width: 18, height: 18)
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.blue)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("No Saved Setlists")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Use the Share menu on the Setlist tab to save a setlist export.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func toggleSelectAll() {
        if allSelected {
            selectedIDs = []
        } else {
            selectedIDs = Set(reportStore.reports.map { $0.id })
        }
    }

    private func deleteSelected() {
        let toDelete = reportStore.reports.filter { selectedIDs.contains($0.id) }
        for item in toDelete {
            try? reportStore.delete(item)
            selectedIDs.remove(item.id)
        }
    }

    // MARK: - Report generation

    private func generateReport() {
        let selected = reportStore.reports.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { return }

        let reports: [SetlistReport]
        do {
            reports = try selected.map { try reportStore.load($0) }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return
        }

        let defaultName: String
        if reports.count == 1 {
            defaultName = "\(reports[0].name) Report.html"
        } else {
            defaultName = "Combined Setlist Report.html"
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.html]
        panel.nameFieldStringValue = defaultName
        panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let reportName = url.deletingPathExtension().lastPathComponent
        let denylistLabels = Set(settings.denylistGenres.map { settings.displayLabel(for: $0).lowercased() })
        let html = HTMLReportGenerator.generate(from: reports, denylistGenres: denylistLabels, reportName: reportName)

        do {
            try html.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(url)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
