import AppKit
import Foundation
import TangoDisplayCore

/// Listens to Swinsian's NSDistributedNotificationCenter push notifications.
///
/// All observer blocks are registered to deliver on OperationQueue.main,
/// matching MusicPoller's contract that callbacks arrive on the main queue.
///
/// Playlist enumeration is unavailable in Swinsian's API; triggerPlaylistFetch()
/// is a no-op and onPlaylistUpdate is never called. AppState's history-based
/// tanda counting fallback handles this automatically.
final class SwinsianMonitor {

    private static let notifyPlaying = "com.swinsian.Swinsian-Track-Playing"
    private static let notifyPaused  = "com.swinsian.Swinsian-Track-Paused"
    private static let notifyStopped = "com.swinsian.Swinsian-Track-Stopped"

    // MARK: - MusicPlayerSource callbacks

    var onTrackUpdate: ((Track?, PlayerState) -> Void)?
    var onPlaylistUpdate: ((tracks: [Track], currentIndex: Int)?) -> Void = { _ in }
    var onNextTrackUpdate: ((Track?) -> Void)? = nil
    var onWatchdogChanged: ((Bool) -> Void)?

    private var observers: [AnyObject] = []

    // MARK: - Artwork (file path via osascript + AVFoundation)

    private static let artworkPathScript = """
        tell application "Swinsian"
            try
                if player state is not stopped then
                    return location of current track
                end if
            end try
            return ""
        end tell
        """

    private func runOsascript(_ script: String) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do { try proc.run() } catch { return nil }
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Lifecycle

    func start() {
        onWatchdogChanged?(false)   // clear any stale watchdog state from previous source

        let nc = DistributedNotificationCenter.default()

        let playingObs = nc.addObserver(
            forName: NSNotification.Name(Self.notifyPlaying),
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handlePlaying(userInfo: note.userInfo)
        }

        let pausedObs = nc.addObserver(
            forName: NSNotification.Name(Self.notifyPaused),
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handlePaused(userInfo: note.userInfo)
        }

        let stoppedObs = nc.addObserver(
            forName: NSNotification.Name(Self.notifyStopped),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onTrackUpdate?(nil, .stopped)
        }

        observers = [playingObs, pausedObs, stoppedObs]
    }

    func stop() {
        let nc = DistributedNotificationCenter.default()
        observers.forEach { nc.removeObserver($0) }
        observers.removeAll()
    }

    // MARK: - Notification handlers

    private func handlePlaying(userInfo: [AnyHashable: Any]?) {
        if let track = parseTrack(from: userInfo) {
            onTrackUpdate?(track, .playing)
        } else {
            onTrackUpdate?(nil, .stopped)
        }
    }

    private func handlePaused(userInfo: [AnyHashable: Any]?) {
        if let track = parseTrack(from: userInfo) {
            onTrackUpdate?(track, .paused)
        } else {
            onTrackUpdate?(nil, .stopped)
        }
    }

    private func parseTrack(from userInfo: [AnyHashable: Any]?) -> Track? {
        guard let info = userInfo,
              let uuid = info["track_uuid"] as? String,
              !uuid.isEmpty
        else { return nil }

        let title   = info["title"]  as? String ?? ""
        let artist  = info["artist"] as? String ?? ""
        let genre   = info["genre"]  as? String ?? ""
        let yearRaw = (info["year"] as? NSNumber)?.intValue
                   ?? Int(info["year"] as? String ?? "")
                   ?? 0
        let year    = yearRaw > 0 ? yearRaw : nil
        return Track(title: title, artist: artist, genre: genre, persistentID: uuid, year: year)
    }
}

// MARK: - MusicPlayerSource conformance

extension SwinsianMonitor: MusicPlayerSource {
    var supportsPlaylist: Bool { false }
    func pollNow()              {}  // push model: no polling
    func triggerPlaylistFetch() {}  // no Swinsian playlist API

    func fetchArtwork(for track: Track) async -> NSImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { [weak self] in
                guard let self else { continuation.resume(returning: nil); return }
                let path = self.runOsascript(Self.artworkPathScript) ?? ""
                continuation.resume(returning: artworkFromAudioFile(path))
            }
        }
    }
}
