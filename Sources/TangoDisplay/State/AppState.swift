import Foundation
import AppKit
import Combine
import TangoDisplayCore

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published state

    @Published private(set) var displayState = DisplayState()
    @Published private(set) var watchdogActive = false
    @Published private(set) var availableDisplays: [DisplayInfo] = []
    @Published private(set) var debugLog: [String] = []
    /// Transient override set by AppearanceSettingsView while editing.
    /// Non-nil only while the Appearance tab is visible; cleared on disappear.
    @Published var draftProfile: AppearanceProfile? = nil
    /// Set by AppearanceSettingsView when the working copy differs from the last saved state.
    @Published var hasUnsavedAppearanceChanges: Bool = false

    // MARK: - Window actions (set by ControlView; used by MenuBarController)

    /// Stored by ControlView so non-SwiftUI code can reopen the presentation window.
    var reopenPresentationWindow: (() -> Void)? = nil

    // MARK: - Services

    let settings = AppSettings()
    let profileStore = ProfileStore()
    private var activeSource: any MusicPlayerSource = MusicPoller()  // replaced in start()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Internal state

    private var trackHistory: [Track] = []           // cleared on each cortina/idle
    private var playlistTracks: [Track]? = nil       // last known playlist; nil = unavailable
    private var playlistCurrentIndex: Int = 0        // 0-based
    private var lastSeenPersistentID: String = ""
    @Published private(set) var currentPlayerState: PlayerState = .stopped
    private var isPausedByUser = false               // ⌘⇧P toggle
    private var pendingStateBeforePause: DisplayState? = nil  // state snapshot for unpausing
    var isDisplayPausedByUser: Bool { isPausedByUser }

    // MARK: - Init

    init() {
        refreshDisplayList()
        registerForScreenChanges()
        // Forward nested ObservableObject changes so PresentationView re-renders
        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        profileStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        observePlayerSelection()
    }

    // MARK: - Lifecycle

    func start() {
        activeSource = AppState.makeSource(for: settings.selectedPlayer)
        wireCallbacks(to: activeSource)
        activeSource.start()
    }

    func pollNow() {
        activeSource.pollNow()
    }

    // MARK: - Source management

    private static func makeSource(for choice: MusicPlayerChoice) -> any MusicPlayerSource {
        switch choice {
        case .musicApp: return MusicPoller()
        case .swinsian: return SwinsianMonitor()
        case .embrace:  return EmbracMonitor()
        }
    }

    private func wireCallbacks(to source: any MusicPlayerSource) {
        source.onTrackUpdate = { [weak self] track, state in
            self?.handleTrackUpdate(track: track, playerState: state)
        }
        source.onPlaylistUpdate = { [weak self] context in
            self?.handlePlaylistUpdate(context)
        }
        source.onWatchdogChanged = { [weak self] active in
            self?.watchdogActive = active
            let name = self?.settings.selectedPlayer.displayName ?? "Player"
            self?.appendDebugLog(active
                ? "⚠ Watchdog active — \(name) unreachable"
                : "✓ \(name) reconnected")
        }
    }

    private func observePlayerSelection() {
        settings.$selectedPlayer
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] choice in self?.switchSource(to: choice) }
            .store(in: &cancellables)
    }

    private func switchSource(to choice: MusicPlayerChoice) {
        activeSource.stop()
        resetTransientState()
        let newSource = AppState.makeSource(for: choice)
        wireCallbacks(to: newSource)
        activeSource = newSource
        activeSource.start()
        appendDebugLog("Switched player to \(choice.displayName)")
    }

    private func resetTransientState() {
        trackHistory.removeAll()
        playlistTracks = nil
        playlistCurrentIndex = 0
        lastSeenPersistentID = ""
        currentPlayerState = .stopped
        isPausedByUser = false
        pendingStateBeforePause = nil
        watchdogActive = false
        displayState = DisplayState()
    }

    // MARK: - Track update (core state machine)

    private func handleTrackUpdate(track: Track?, playerState: PlayerState) {
        // Skip duplicate polls
        let pid = track?.persistentID ?? ""
        guard pid != lastSeenPersistentID || playerState != currentPlayerState else { return }
        lastSeenPersistentID = pid
        currentPlayerState = playerState

        // Stopped
        if playerState == .stopped || track == nil {
            trackHistory.removeAll()
            displayState = DisplayState()   // mode = .idle
            isPausedByUser = false
            pendingStateBeforePause = nil
            return
        }

        guard let track else { return }

        // Override mode: ignore track changes
        if displayState.mode == .override { return }

        // User-paused: update internal state but freeze display
        if isPausedByUser {
            // Still update playlist-derived info in the background but don't mutate displayState
            updateTandaPositionQuietly(track: track)
            return
        }

        // Player paused (not user-initiated): show track but indicate paused
        if playerState == .paused {
            if trackHistory.last?.persistentID != track.persistentID {
                trackHistory.append(track)
            }
            let detector = settings.makeDetector()
            let position = computeTandaPosition(track: track, detector: detector)
            displayState = DisplayState(
                mode: .paused,
                currentTrack: track,
                nextTrack: nil,
                tandaPosition: position,
                overrideText: nil
            )
            return
        }

        let detector = settings.makeDetector()
        let trackIsCortina = detector.isCortina(genre: track.genre)

        if trackIsCortina {
            let raw = track.genre
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if raw.isEmpty {
                appendDebugLog("⚠ '\(track.title)' has empty genre — classified as cortina (check player tags)")
            } else if raw != trimmed {
                appendDebugLog("⚠ '\(track.title)' genre \(raw.debugDescription) has leading/trailing whitespace — classified as cortina after trimming to \(trimmed.debugDescription)")
            }
        }

        if trackIsCortina {
            handleCortinaTrack(track: track, detector: detector)
        } else {
            handleDanceTrack(track: track, detector: detector)
        }
    }

    private func handleCortinaTrack(track: Track, detector: CortinaDetector) {
        // Anchor playlistCurrentIndex to the cortina's real position.
        // playlistCurrentIndex may be stale if the user skipped tracks or
        // double-clicked a cortina — the playlist context only refreshes every 20s.
        if let tracks = playlistTracks,
           let idx = tracks.firstIndex(where: { $0.persistentID == track.persistentID }) {
            playlistCurrentIndex = idx
        }

        // Trigger a fresh playlist fetch so the look-ahead reflects the current playlist.
        // handlePlaylistUpdate will update or clear nextTrack when the result arrives.
        activeSource.triggerPlaylistFetch()

        // Find the next non-cortina track (first track of next tanda) from playlist
        let nextTrack = findNextDanceTrack(after: playlistCurrentIndex, detector: detector)
        trackHistory.removeAll()
        displayState = DisplayState(
            mode: .cortina,
            currentTrack: track,
            nextTrack: nextTrack,
            tandaPosition: nil,
            overrideText: nil
        )
    }

    private func handleDanceTrack(track: Track, detector: CortinaDetector) {
        let comingFromPlaying = (displayState.mode == .playing)
        let comingFromCortina = (displayState.mode == .cortina)

        // If transitioning from cortina/idle, start fresh history
        if displayState.mode == .cortina || displayState.mode == .idle {
            trackHistory.removeAll()
        }

        // Append to history if it's a new track
        if trackHistory.last?.persistentID != track.persistentID {
            trackHistory.append(track)
        }

        // If we transitioned from .playing or .cortina and the new track isn't in the
        // known playlist (different playlist loaded), the history-based count can't be
        // trusted. Reset history, suppress the counter, and fetch fresh playlist data.
        // handlePlaylistUpdate will set the correct position.
        let trackInPlaylist = playlistTracks?.contains(where: { $0.persistentID == track.persistentID }) ?? false
        if (comingFromPlaying || comingFromCortina) && !trackInPlaylist {
            trackHistory = [track]
            activeSource.triggerPlaylistFetch()
            displayState = DisplayState(
                mode: .playing,
                currentTrack: track,
                nextTrack: nil,
                tandaPosition: nil,
                overrideText: nil
            )
            return
        }

        // Guarantee a non-nil position: history always has at least 1 track at this point
        let position = computeTandaPosition(track: track, detector: detector)
            ?? TandaPosition(current: max(1, trackHistory.count), total: nil)
        displayState = DisplayState(
            mode: .playing,
            currentTrack: track,
            nextTrack: nil,
            tandaPosition: position,
            overrideText: nil
        )
    }

    private func updateTandaPositionQuietly(track: Track) {
        // Called when paused: keep history up to date so it's ready on unpause
        if trackHistory.last?.persistentID != track.persistentID {
            trackHistory.append(track)
        }
    }

    // MARK: - Playlist update

    private func handlePlaylistUpdate(_ context: (tracks: [Track], currentIndex: Int)?) {
        guard let context else {
            playlistTracks = nil
            return
        }
        playlistTracks = context.tracks
        playlistCurrentIndex = context.currentIndex

        // Re-derive tanda position with updated playlist data (only update if non-nil to
        // avoid clearing a working history-based position when the playlist path fails)
        if displayState.mode == .playing, let current = displayState.currentTrack {
            let detector = settings.makeDetector()
            if let position = computeTandaPosition(track: current, detector: detector),
               displayState.tandaPosition != position {
                displayState.tandaPosition = position
            }
        }

        // Re-evaluate cortina look-ahead with fresh data. If the cortina is no longer
        // in the new playlist (user switched playlists), clear the stale next-track display.
        if displayState.mode == .cortina, let currentTrack = displayState.currentTrack {
            let detector = settings.makeDetector()
            if let tracks = playlistTracks,
               let idx = tracks.firstIndex(where: { $0.persistentID == currentTrack.persistentID }) {
                playlistCurrentIndex = idx
                displayState.nextTrack = findNextDanceTrack(after: idx, detector: detector)
            } else {
                displayState.nextTrack = nil
            }
        }
    }

    // MARK: - Override

    func activateOverride(text: String) {
        displayState.overrideText = text
        displayState.mode = .override
    }

    func clearOverride() {
        displayState.overrideText = nil
        displayState.mode = .idle
        isPausedByUser = false          // don't inherit a pre-override user-pause
        pendingStateBeforePause = nil
        lastSeenPersistentID = ""       // force re-evaluation on next poll
        currentPlayerState = .stopped
    }

    // MARK: - Pause toggle (⌘⇧P)

    func togglePaused() {
        if isPausedByUser {
            isPausedByUser = false
            pendingStateBeforePause = nil
            // Reset the dedup guard so the next poll re-evaluates current player state.
            // Restoring the pre-pause snapshot is unsafe — the player state may have changed
            // while the display was frozen, so currentPlayerState is already stale and the
            // guard would permanently skip the correction poll.
            lastSeenPersistentID = ""
            currentPlayerState = .stopped
            displayState = DisplayState()   // idle until the poll arrives
            pollNow()                       // trigger immediately rather than waiting up to 2s
        } else {
            isPausedByUser = true
            pendingStateBeforePause = displayState
            displayState.mode = .paused
        }
    }

    // MARK: - Display list

    func refreshDisplayList() {
        availableDisplays = NSScreen.screens.map { screen in
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            return DisplayInfo(
                id: displayID,
                name: screen.localizedName,
                frame: screen.frame,
                isMain: screen == NSScreen.main
            )
        }
    }

    private func registerForScreenChanges() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshDisplayList()
            }
        }
    }

    // MARK: - Debug log

    func appendDebugLog(_ message: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        debugLog.append("[\(ts)] \(message)")
        if debugLog.count > 200 {
            debugLog.removeFirst(debugLog.count - 200)
        }
    }

    // MARK: - Helpers

    /// Finds the first non-cortina track after `afterIndex` in the known playlist.
    private func findNextDanceTrack(after afterIndex: Int, detector: CortinaDetector) -> Track? {
        guard let tracks = playlistTracks else { return nil }
        let startSearch = afterIndex + 1
        guard startSearch < tracks.count else { return nil }
        return tracks[startSearch...].first { !detector.isCortina(genre: $0.genre) }
    }

    /// Computes tanda position: playlist-based if available, history-based as fallback.
    private func computeTandaPosition(track: Track, detector: CortinaDetector) -> TandaPosition? {
        let tracker = TandaTracker()

        if let tracks = playlistTracks {
            // Find current track's index in the playlist by persistentID
            if let idx = tracks.firstIndex(where: { $0.persistentID == track.persistentID }) {
                playlistCurrentIndex = idx
                if let pos = tracker.position(tracks: tracks, currentIndex: idx, detector: detector) {
                    return pos
                }
                // position() returned nil (e.g. genre mismatch classified track as cortina in
                // the playlist copy) — fall through to history-based fallback below
            }
        }

        // Fallback: history-based
        return tracker.positionFromHistory(trackHistory)
    }
}

// MARK: - DisplayInfo

struct DisplayInfo: Identifiable {
    let id: CGDirectDisplayID
    let name: String
    let frame: CGRect
    let isMain: Bool
}
