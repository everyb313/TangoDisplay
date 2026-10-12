import Foundation

struct SetlistReportMetadata: Identifiable {
    let id: UUID
    let name: String
    let exportDate: Date
    let trackCount: Int
    let fileURL: URL
}

final class SetlistReportStore: ObservableObject {
    @Published private(set) var reports: [SetlistReportMetadata] = []

    private let reportsDir: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("TangoDisplay/setlist-reports")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    init() { refresh() }

    func refresh() {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: reportsDir, includingPropertiesForKeys: nil) else {
            reports = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        reports = items
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> SetlistReportMetadata? in
                guard let data = try? Data(contentsOf: url),
                      let report = try? decoder.decode(SetlistReport.self, from: data) else { return nil }
                return SetlistReportMetadata(
                    id: report.id,
                    name: report.name,
                    exportDate: report.exportDate,
                    trackCount: report.entries.count,
                    fileURL: url
                )
            }
            .sorted { $0.exportDate > $1.exportDate }
    }

    func save(_ report: SetlistReport) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(report)
        let sanitized = sanitizeName(report.name)
        let filename = "\(sanitized)-\(report.id.uuidString).json"
        let url = reportsDir.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        refresh()
    }

    func delete(_ metadata: SetlistReportMetadata) throws {
        try FileManager.default.removeItem(at: metadata.fileURL)
        refresh()
    }

    func rename(_ metadata: SetlistReportMetadata, to newName: String) throws {
        let old = try load(metadata)
        try save(SetlistReport(id: old.id, name: newName, exportDate: old.exportDate, entries: old.entries))
        // Filename embeds sanitized name; same sanitized name means save() overwrote the original file.
        if sanitizeName(newName) != sanitizeName(old.name) {
            try FileManager.default.removeItem(at: metadata.fileURL)
            refresh()
        }
    }

    func load(_ metadata: SetlistReportMetadata) throws -> SetlistReport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try Data(contentsOf: metadata.fileURL)
        return try decoder.decode(SetlistReport.self, from: data)
    }

    private func sanitizeName(_ name: String) -> String {
        let cleaned = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        return String(cleaned.prefix(60)).isEmpty ? "setlist" : String(cleaned.prefix(60))
    }
}
