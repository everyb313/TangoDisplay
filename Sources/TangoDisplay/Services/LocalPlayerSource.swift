import AVFoundation
import AppKit
import Combine
import Foundation
import OSLog
import TangoDisplayCore

final class LocalPlayerSource: NSObject, ObservableObject, MusicPlayerSource {

    // MARK: - MusicPlayerSource callbacks

    var onTrackUpdate: ((Track?, PlayerState) -> Void)?
    var onPlaylistUpdate: ((tracks: [Track], currentIndex: Int)?) -> Void = { _ in }
    var onNextTrackUpdate: ((Track?) -> Void)?
    var onWatchdogChanged: ((Bool) -> Void)?
    var supportsPlaylist: Bool { true }
    var isTransportControllable: Bool { true }

    // MARK: - Observable playback state (for PlayerControlsView)

    @Published private(set) var elapsed: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var currentEntryID: UUID?
    @Published private(set) var isCurrentEntryMarkedAsPlayed: Bool = false
    @Published private(set) var isActivePlaying: Bool = false

    var volume: Float {
        get { playerNode.volume }
        set { playerNode.volume = max(0, min(1, newValue)) }
    }

    private var _balance: Float = 0
    var balance: Float {
        get { _balance }
        set { _balance = max(-1, min(1, newValue)); applyBalance(_balance) }
    }

    // MARK: - Private — audio engine

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 5)
    private let balanceMixer = AVAudioMixerNode()
    private var audioFile: AVAudioFile?
    private var seekOffset: Double = 0

    // MARK: - Level meter

    private(set) var levelMeter: AudioLevelMeter!

    // MARK: - Private — state

    let setlist: SetlistManager
    private let settings: AppSettings
    private var timeObserverTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var earlyMarkedEntryIDs: Set<UUID> = []
    private var scheduleGeneration: Int = 0

    // MARK: - Private — auto-gap

    private var currentPaddingFrames: AVAudioFrameCount = 0
    private var prevTrackSilenceAtEnd: Double = 0   // populated by background analysis of the track that just played
    private var nextTrackSilenceAtStart: Double = 0 // populated by background analysis of the upcoming track
    private var audioStartSampleTime: AVAudioFramePosition = 0
    private var silencePending: Bool = false

    // MARK: - Init

    init(setlist: SetlistManager, settings: AppSettings, volume: Float = 1.0) {
        self.setlist = setlist
        self.settings = settings
        super.init()
        setupAudioEngine()
        levelMeter = AudioLevelMeter(mixerNode: audioEngine.mainMixerNode)
        playerNode.volume = max(0, min(1, volume))
        applyOutputDevice(settings.builtInOutputDeviceUID)
        applyEQGains(settings.eqGains)
        _balance = max(-1, min(1, settings.builtInBalance))
        applyBalance(_balance)
    }

    // MARK: - Audio engine setup

    private func setupAudioEngine() {
        audioEngine.attach(playerNode)
        audioEngine.attach(eq)
        audioEngine.attach(balanceMixer)
        audioEngine.connect(playerNode, to: eq, format: nil)
        audioEngine.connect(eq, to: balanceMixer, format: nil)
        audioEngine.connect(balanceMixer, to: audioEngine.mainMixerNode, format: nil)

        let frequencies: [Float]          = [60, 250, 1000, 4000, 12000]
        let filterTypes: [AVAudioUnitEQFilterType] = [.lowShelf, .parametric, .parametric, .parametric, .highShelf]
        for (i, band) in eq.bands.enumerated() {
            band.filterType = filterTypes[i]
            band.frequency  = frequencies[i]
            band.bandwidth  = 1.0
            band.gain       = 0.0
            band.bypass     = false
        }

        try? audioEngine.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEngineConfigChange),
            name: .AVAudioEngineConfigurationChange,
            object: audioEngine
        )
    }

    @objc private func handleEngineConfigChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let file = self.audioFile {
                self.audioEngine.disconnectNodeOutput(self.playerNode)
                self.audioEngine.disconnectNodeOutput(self.eq)
                self.audioEngine.disconnectNodeOutput(self.balanceMixer)
                self.audioEngine.connect(self.playerNode, to: self.eq, format: file.processingFormat)
                self.audioEngine.connect(self.eq, to: self.balanceMixer, format: file.processingFormat)
                self.audioEngine.connect(self.balanceMixer, to: self.audioEngine.mainMixerNode, format: file.processingFormat)
            }
            do {
                try self.audioEngine.start()
                self.levelMeter.engineDidReconfigure()
                self.levelMeter.reinstallTap()
                self.applyBalance(self._balance)
            } catch {
                os_log(.error, "TangoDisplay: engine restart failed: %{public}@", error.localizedDescription)
            }
            guard self.audioFile != nil else { return }
            self.seekTo(self.elapsed)
            if self.isActivePlaying { self.playerNode.play() }
        }
    }

    private func applyOutputDevice(_ uid: String) {
        guard let audioUnit = audioEngine.outputNode.audioUnit else { return }
        if uid.isEmpty {
            // Restore default device by reading system default
            var defaultID = AudioDeviceID(0)
            var size = UInt32(MemoryLayout<AudioDeviceID>.size)
            var addr = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &defaultID)
            AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_CurrentDevice,
                                 kAudioUnitScope_Global, 0, &defaultID, size)
        } else if var deviceID = AudioDeviceManager.audioDeviceID(forUID: uid) {
            AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_CurrentDevice,
                                 kAudioUnitScope_Global, 0, &deviceID,
                                 UInt32(MemoryLayout<AudioDeviceID>.size))
        }
    }

    private func applyEQGains(_ gains: [Float]) {
        for (i, band) in eq.bands.enumerated() where i < gains.count {
            band.gain = gains[i]
        }
    }

    private func applyBalance(_ pan: Float) {
        balanceMixer.pan = pan
    }

    // MARK: - MusicPlayerSource lifecycle

    func start() {
        setupObservers()
        reportCurrentState()
        reportPlaylist()
    }

    func stop() {
        currentEntryID = nil
        isCurrentEntryMarkedAsPlayed = false
        isActivePlaying = false
        playerNode.stop()
        audioEngine.stop()
        levelMeter.reset()
        audioFile = nil
        elapsed = 0
        duration = 0
        currentPaddingFrames = 0
        silencePending = false
        audioStartSampleTime = 0
        prevTrackSilenceAtEnd = 0
        nextTrackSilenceAtStart = 0
        teardownObservers()
    }

    func pollNow() {
        reportCurrentState()
        reportPlaylist()
    }

    func triggerPlaylistFetch() {
        reportPlaylist()
    }

    func fetchArtwork(for track: Track) async -> NSImage? {
        guard let url = URL(string: track.persistentID), url.isFileURL else { return nil }
        let asset = AVURLAsset(url: url)
        guard let metadata = try? await asset.load(.metadata) else { return nil }
        let items = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: .commonIdentifierArtwork)
        guard let item = items.first,
              let data = try? await item.load(.dataValue) else { return nil }
        return NSImage(data: data)
    }

    // MARK: - Transport controls

    func play() {
        if let id = currentEntryID, earlyMarkedEntryIDs.contains(id) || currentEntryIsPlayed() {
            skipNext()
            return
        }
        if audioFile == nil {
            // Prefer currentEntryID if set (e.g. pause() advanced it to the next track);
            // fall back to first non-played entry for a fresh start.
            let entry: SetlistEntry?
            if let id = currentEntryID {
                entry = setlist.entries.first(where: { $0.id == id })
            } else {
                entry = setlist.entries.first(where: { $0.state != .played })
            }
            guard let entry else { return }
            loadEntry(entry)
            playerNode.play()
            isActivePlaying = true
        } else if let id = currentEntryID {
            setlist.markPlaying(id: id)
            seekTo(0) { [weak self] in
                self?.playerNode.play()
                self?.isActivePlaying = true
            }
        }
        reportCurrentState()
    }

    func pause() {
        scheduleGeneration += 1
        playerNode.stop()
        isActivePlaying = false
        if let id = currentEntryID, !earlyMarkedEntryIDs.contains(id), !currentEntryIsPlayed() {
            setlist.markPaused(id: id)
            seekTo(0)
            elapsed = 0
            reportCurrentState()
        } else if let id = currentEntryID, let nextEntry = setlist.firstUnplayed(after: id) {
            audioFile = nil
            seekOffset = 0
            currentEntryID = nextEntry.id
            elapsed = 0
            duration = nextEntry.duration ?? 0
            reportCurrentState()
            reportPlaylist()
            onNextTrackUpdate?(setlist.entry(after: nextEntry.id)?.track)
        } else {
            audioFile = nil
            seekOffset = 0
            currentEntryID = nil
            elapsed = 0
            duration = 0
            reportCurrentState()
            reportPlaylist()
            onNextTrackUpdate?(nil)
        }
    }

    func stopTrack() {
        if let id = currentEntryID, !earlyMarkedEntryIDs.contains(id), !currentEntryIsPlayed() {
            setlist.markQueued(id: id)
        }
        scheduleGeneration += 1
        currentEntryID = nil
        isCurrentEntryMarkedAsPlayed = false
        isActivePlaying = false
        playerNode.stop()
        audioFile = nil
        elapsed = 0
        duration = 0
        seekOffset = 0
        currentPaddingFrames = 0
        silencePending = false
        audioStartSampleTime = 0
        prevTrackSilenceAtEnd = 0
        nextTrackSilenceAtStart = 0
        reportCurrentState()
        reportPlaylist()
        onNextTrackUpdate?(nil)
    }

    func skipNext() {
        guard let id = currentEntryID else { play(); return }
        let shouldStop = (id == setlist.stopAfterEntryID)
        setlist.markPlayed(id: id)
        if shouldStop { setlist.stopAfterEntryID = nil }
        if !shouldStop, let next = setlist.firstUnplayed(after: id) {
            loadEntry(next)
            playerNode.play()
            isActivePlaying = true
            reportCurrentState()
        } else {
            currentEntryID = nil
            isActivePlaying = false
            playerNode.stop()
            audioFile = nil
            elapsed = 0
            duration = 0
            seekOffset = 0
            reportCurrentState()
            reportPlaylist()
            onNextTrackUpdate?(nil)
        }
    }

    func skipPrevious() {
        if elapsed > 3 {
            seek(to: 0)
            return
        }
        guard let id = currentEntryID else { return }
        if let prev = setlist.entry(before: id) {
            let wasPlaying = isActivePlaying
            loadEntry(prev)
            if wasPlaying { playerNode.play(); isActivePlaying = true; reportCurrentState() }
        } else {
            seek(to: 0)
        }
    }

    func seek(to seconds: Double) {
        seekTo(seconds)
    }

    // MARK: - Jump to a specific entry (double-click in SetlistView)

    func jumpTo(_ entry: SetlistEntry) {
        loadEntry(entry)
        playerNode.play()
        isActivePlaying = true
        reportCurrentState()
    }

    // MARK: - Private: seek implementation

    private func seekTo(_ seconds: Double, completion: (() -> Void)? = nil) {
        guard let file = audioFile else { completion?(); return }
        let sampleRate = file.fileFormat.sampleRate
        let startFrame = AVAudioFramePosition(max(0, seconds) * sampleRate)
        let totalFrames = file.length
        guard startFrame < totalFrames else { completion?(); return }
        let frameCount = AVAudioFrameCount(totalFrames - startFrame)
        let wasPlaying = playerNode.isPlaying
        playerNode.stop()
        seekOffset = seconds
        elapsed = seconds
        currentPaddingFrames = 0
        silencePending = false
        audioStartSampleTime = 0
        scheduleGeneration += 1
        let gen = scheduleGeneration
        playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount,
                                   at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            DispatchQueue.main.async { self?.handleTrackEnd(generation: gen) }
        }
        if wasPlaying { playerNode.play() }
        completion?()
    }

    // MARK: - Private: entry loading

    private func loadEntry(_ entry: SetlistEntry) {
        earlyMarkedEntryIDs.remove(entry.id)
        isCurrentEntryMarkedAsPlayed = false
        playerNode.stop()
        scheduleGeneration += 1
        let gen = scheduleGeneration
        do {
            let file = try AVAudioFile(forReading: entry.fileURL)
            audioFile = file
            seekOffset = 0
            elapsed = 0
            duration = Double(file.length) / file.fileFormat.sampleRate
            // scheduleFile requires the file format to exactly match the output bus format.
            // Stop the engine before reconnecting so the graph is in a clean state; a mono
            // AIFF scheduled against the stereo-defaulted startup connection produces silence.
            audioEngine.stop()
            audioEngine.disconnectNodeOutput(playerNode)
            audioEngine.disconnectNodeOutput(eq)
            audioEngine.disconnectNodeOutput(balanceMixer)
            audioEngine.connect(playerNode, to: eq, format: file.processingFormat)
            audioEngine.connect(eq, to: balanceMixer, format: file.processingFormat)
            audioEngine.connect(balanceMixer, to: audioEngine.mainMixerNode, format: file.processingFormat)
            try audioEngine.start()
            levelMeter.reinstallTap()

            // Auto-gap: schedule silence before the file if needed.
            // nextTrackSilenceAtStart is pre-populated by the background analysis from the previous track's loadEntry.
            currentPaddingFrames = 0
            silencePending = false
            audioStartSampleTime = 0
            let isFirstTrack = setlist.entries.first?.id == entry.id
                && !setlist.entries.contains(where: { $0.state == .played })
            var autoGapApplied = false
            var autoGapSkipped = false
            if !entry.ignoresAutoGap && settings.autoGapEnabled {
                if settings.autoGapIgnoreFirstTrack && isFirstTrack {
                    autoGapSkipped = true
                } else {
                    let padding = computeAutoGapPadding(
                        prevSilenceAtEnd: prevTrackSilenceAtEnd,
                        nextSilenceAtStart: nextTrackSilenceAtStart,
                        minimumSilence: settings.autoGapDuration
                    )
                    if padding > 0 {
                        let frames = AVAudioFrameCount(padding * file.fileFormat.sampleRate)
                        silencePending = true
                        let entryID = entry.id
                        playerNode.scheduleBuffer(
                            makeSilenceBuffer(format: file.processingFormat, frameCount: frames),
                            completionCallbackType: .dataConsumed
                        ) { [weak self] _ in
                            DispatchQueue.main.async {
                                guard let self,
                                      let nodeTime = self.playerNode.lastRenderTime,
                                      nodeTime.isSampleTimeValid,
                                      let pt = self.playerNode.playerTime(forNodeTime: nodeTime) else { return }
                                self.audioStartSampleTime = pt.sampleTime
                                self.silencePending = false
                                self.setlist.setAutoGapApplied(id: entryID, applied: false)
                            }
                        }
                        currentPaddingFrames = frames
                        autoGapApplied = true
                    }
                }
            }
            setlist.setAutoGapApplied(id: entry.id, applied: autoGapApplied)
            setlist.setAutoGapSkipped(id: entry.id, skipped: autoGapSkipped)
            prevTrackSilenceAtEnd = 0
            nextTrackSilenceAtStart = 0

            playerNode.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                DispatchQueue.main.async { self?.handleTrackEnd(generation: gen) }
            }

            // Analyze current track's end-silence and pre-warm next track's start-silence in background.
            let currentURL = entry.fileURL
            let nextURL = setlist.entry(after: entry.id)?.fileURL
            Task { [weak self] in
                let result = await AudioSilenceAnalyzer.shared.analyze(url: currentURL)
                let nextStart: Double
                if let nextURL {
                    let nextResult = await AudioSilenceAnalyzer.shared.analyze(url: nextURL)
                    nextStart = nextResult.silenceAtStart
                } else {
                    nextStart = 0
                }
                await MainActor.run { [weak self] in
                    self?.prevTrackSilenceAtEnd = result.silenceAtEnd
                    self?.nextTrackSilenceAtStart = nextStart
                }
            }
        } catch {
            os_log(.error, "TangoDisplay: failed to load %{public}@: %{public}@",
                   entry.fileURL.path, error.localizedDescription)
            audioFile = nil
        }
        currentEntryID = entry.id
        setlist.markPlaying(id: entry.id)
        reportCurrentState()
        reportPlaylist()
        onNextTrackUpdate?(setlist.entry(after: entry.id)?.track)
    }

    private func handleTrackEnd(generation: Int) {
        guard generation == scheduleGeneration else { return }
        skipNext()
    }

    private func computeAutoGapPadding(
        prevSilenceAtEnd: Double,
        nextSilenceAtStart: Double,
        minimumSilence: Double
    ) -> Double {
        guard minimumSilence > 0 else { return 0 }
        let existing = prevSilenceAtEnd + nextSilenceAtStart
        let needed = max(0, minimumSilence - existing)
        // Matches Embrace: if existing silence already meets minimum, still add 1s so the gap is perceptible.
        return needed == 0 ? 1.0 : needed
    }

    private func makeSilenceBuffer(format: AVAudioFormat, frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer {
        // AVAudioPCMBuffer is zero-initialized, so this is already silent.
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buf.frameLength = frameCount
        return buf
    }

    private func currentEntryIsPlayed() -> Bool {
        guard let id = currentEntryID else { return false }
        return setlist.entries.first(where: { $0.id == id })?.state == .played
    }

    // MARK: - Private: observers

    private func setupObservers() {
        timeObserverTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.updateTime() }

        settings.$builtInOutputDeviceUID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] uid in self?.applyOutputDevice(uid) }
            .store(in: &cancellables)

        settings.$eqBand0Gain.sink { [weak self] v in self?.eq.bands[0].gain = v }.store(in: &cancellables)
        settings.$eqBand1Gain.sink { [weak self] v in self?.eq.bands[1].gain = v }.store(in: &cancellables)
        settings.$eqBand2Gain.sink { [weak self] v in self?.eq.bands[2].gain = v }.store(in: &cancellables)
        settings.$eqBand3Gain.sink { [weak self] v in self?.eq.bands[3].gain = v }.store(in: &cancellables)
        settings.$eqBand4Gain.sink { [weak self] v in self?.eq.bands[4].gain = v }.store(in: &cancellables)

        settings.$builtInBalance
            .dropFirst()
            .sink { [weak self] v in self?.balance = v }
            .store(in: &cancellables)

        setlist.$entries
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                guard let self else { return }
                // Remove early-mark for entries removed from setlist or explicitly unmarked as played.
                let playedIDs = Set(entries.filter { $0.state == .played }.map(\.id))
                self.earlyMarkedEntryIDs.formIntersection(playedIDs)
                if let id = self.currentEntryID, !self.earlyMarkedEntryIDs.contains(id) {
                    self.isCurrentEntryMarkedAsPlayed = false
                }
                if let id = self.currentEntryID,
                   !entries.contains(where: { $0.id == id }) {
                    self.currentEntryID = nil
                    self.isActivePlaying = false
                    self.playerNode.stop()
                    self.audioFile = nil
                    self.elapsed = 0
                    self.duration = 0
                    self.seekOffset = 0
                    self.reportCurrentState()
                    self.reportPlaylist()
                    self.onNextTrackUpdate?(nil)
                }
                if let id = self.currentEntryID, self.audioFile == nil,
                   let entry = entries.first(where: { $0.id == id }),
                   let d = entry.duration, d != self.duration {
                    self.duration = d
                }
                if let id = self.currentEntryID, self.audioFile == nil, !self.isActivePlaying,
                   entries.first(where: { $0.id == id })?.state == .played {
                    if let next = self.setlist.firstUnplayed(after: id) {
                        self.currentEntryID = next.id
                        self.elapsed = 0
                        self.duration = next.duration ?? 0
                        self.reportCurrentState()
                        self.reportPlaylist()
                        self.onNextTrackUpdate?(self.setlist.entry(after: next.id)?.track)
                    } else {
                        self.currentEntryID = nil
                        self.elapsed = 0
                        self.duration = 0
                        self.reportCurrentState()
                        self.reportPlaylist()
                        self.onNextTrackUpdate?(nil)
                    }
                }
                if self.currentEntryID == nil, self.audioFile == nil,
                   let firstQueued = entries.first(where: { $0.state == .queued }) {
                    self.currentEntryID = firstQueued.id
                    self.elapsed = 0
                    self.duration = firstQueued.duration ?? 0
                    self.reportCurrentState()
                    self.reportPlaylist()
                    self.onNextTrackUpdate?(self.setlist.entry(after: firstQueued.id)?.track)
                }
                // A reorder may have inserted a queued track before our queued-but-not-yet-loaded
                // current entry. Promote the new first-queued entry to be the current one.
                if let id = self.currentEntryID, self.audioFile == nil, !self.isActivePlaying,
                   entries.first(where: { $0.id == id })?.state == .queued,
                   let firstQueued = entries.first(where: { $0.state == .queued }),
                   firstQueued.id != id {
                    self.currentEntryID = firstQueued.id
                    self.elapsed = 0
                    self.duration = firstQueued.duration ?? 0
                    self.reportCurrentState()
                    self.reportPlaylist()
                    self.onNextTrackUpdate?(self.setlist.entry(after: firstQueued.id)?.track)
                }
                // Always report so AppState recalculates tanda position on any entries
                // change, including pure reorders that don't trigger any branch above.
                self.reportPlaylist()
            }
            .store(in: &cancellables)
    }

    private func teardownObservers() {
        timeObserverTimer = nil
        cancellables.removeAll()
    }

    // MARK: - Private: time update

    private func updateTime() {
        guard isActivePlaying,
              let file = audioFile,
              let nodeTime = playerNode.lastRenderTime,
              nodeTime.isSampleTimeValid,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else { return }

        guard !silencePending else { elapsed = 0; return }
        let sampleRate = file.fileFormat.sampleRate
        guard sampleRate > 0 else { return }
        let audioFrames = max(0, playerTime.sampleTime - audioStartSampleTime)
        let newElapsed = seekOffset + Double(audioFrames) / sampleRate
        elapsed = max(0, min(newElapsed, duration))
        duration = Double(file.length) / sampleRate

        if !settings.markAsPlayedAfterCompletion,
           let id = currentEntryID,
           !earlyMarkedEntryIDs.contains(id),
           duration > 0,
           elapsed >= Double(settings.markAsPlayedAfterSeconds) {
            earlyMarkedEntryIDs.insert(id)
            isCurrentEntryMarkedAsPlayed = true
            setlist.markPlayed(id: id)
            reportPlaylist()
        }
    }

    // MARK: - Private: state reporting

    private func reportCurrentState() {
        guard let id = currentEntryID,
              let entry = setlist.entries.first(where: { $0.id == id })
        else {
            isActivePlaying = false
            onTrackUpdate?(nil, .stopped)
            return
        }
        let state: PlayerState = isActivePlaying ? .playing : .paused
        onTrackUpdate?(entry.track, state)
    }

    private func reportPlaylist() {
        let entries = setlist.entries
        guard !entries.isEmpty else { onPlaylistUpdate(nil); return }
        let tracks = entries.map { $0.track }
        let idx = entries.firstIndex(where: { $0.id == currentEntryID }) ?? 0
        onPlaylistUpdate((tracks: tracks, currentIndex: idx))
    }
}
