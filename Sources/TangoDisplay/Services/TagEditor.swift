import AppKit
import Foundation
import TangoDisplayObjC

/// Writes tags into a setlist track's file — Setlist's "Edit Tags…". The TagRoom design:
/// write into a temp copy beside the file, then swap it in atomically, so a crash or full
/// disk never leaves a half-written file. The swap keeps the old inode alive, so a track
/// that is playing carries on from its open handle.
///
/// Tracks dropped from Music are copies in our app-support cache; for those the Music
/// library's own file is rewritten too, and Music is told to `refresh` it.
enum TagEditor {
    struct Failure: LocalizedError { let errorDescription: String? }

    /// TagLib writes all of these; `.caf` has no tag container it supports.
    static func canWrite(_ url: URL) -> Bool {
        let fm = FileManager.default
        return ["mp3", "m4a", "aiff", "aif", "wav", "flac", "opus"].contains(url.pathExtension.lowercased())
            && fm.isWritableFile(atPath: url.path)
            && fm.isWritableFile(atPath: url.deletingLastPathComponent().path)   // temp copy lives here
    }

    /// Writes `changes` (TagLib property names → value, "" clears) to the entry's file and,
    /// for a Music drop, to the library original. Throws only if the setlist file itself
    /// wasn't written; a problem with the Music side comes back as a warning instead.
    static func apply(_ changes: [String: String], to entry: SetlistEntry) async throws -> String? {
        let fileURL = entry.fileURL
        // Spliced into AppleScript below, so accept only the hex form Music hands out.
        let musicID = entry.musicPersistentID.flatMap { $0.allSatisfy(\.isHexDigit) ? $0 : nil }
        return try await Task.detached(priority: .userInitiated) {
            try write(changes, to: fileURL)
            guard let musicID else { return nil }
            guard let original = musicLocation(persistentID: musicID) else {
                return "Tags saved, but the track couldn't be found in Music — its library file is unchanged."
            }
            if original.standardizedFileURL != fileURL.standardizedFileURL {
                do { try write(changes, to: original) } catch {
                    return "Tags saved, but Music's library file couldn't be written: \(error.localizedDescription)"
                }
            }
            runMusic("refresh (first track of library playlist 1 whose persistent ID is \"\(musicID)\")")
            return nil
        }.value
    }

    static func write(_ changes: [String: String], to url: URL) throws {
        let fm = FileManager.default
        // Keep the extension: TagLib picks the format from it.
        let temp = url.deletingLastPathComponent()
            .appendingPathComponent(".tangodisplay-\(UUID().uuidString).\(url.pathExtension)")
        try fm.copyItem(at: url, to: temp)
        do {
            var err: NSString?
            guard TDWriteTags(temp.path, changes, &err) else {
                throw Failure(errorDescription: (err as String?) ?? "Tag write failed")
            }
            _ = try fm.replaceItemAt(url, withItemAt: temp)
        } catch {
            try? fm.removeItem(at: temp)
            throw error
        }
    }

    // MARK: - Music

    /// The Music library file for a persistent ID (same %016llX form AppleScript uses).
    /// ponytail: launches Music if it isn't running — ITLibrary avoids that but costs a ~5s
    /// full-library location scan. Swap in if launching Music mid-milonga bothers anyone.
    private static func musicLocation(persistentID: String) -> URL? {
        let path = runMusic("POSIX path of (get location of (first track of library playlist 1 whose persistent ID is \"\(persistentID)\"))")
        return path.flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
    }

    @discardableResult
    private static func runMusic(_ statement: String) -> String? {
        var errorInfo: NSDictionary?
        let source = "tell application \"Music\"\n\(statement)\nend tell"
        let result = NSAppleScript(source: source)?.executeAndReturnError(&errorInfo)
        return errorInfo == nil ? result?.stringValue : nil
    }
}
