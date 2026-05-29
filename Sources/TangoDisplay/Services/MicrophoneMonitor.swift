import Accelerate
import AVFoundation
import Foundation
import os

/// Monitors the built-in microphone and publishes room level as an integer on 0–140.
///
/// Threading contract (identical to AudioLevelMeter):
///   • processBuffer(_:) fires on the real-time audio I/O thread.
///     It only writes to rawLock — never touches @Published properties.
///   • A 30 fps Timer on RunLoop.main reads the lock and updates @Published properties.
///   • start() / stop() / startEngine() must be called on the main thread.
final class MicrophoneMonitor: ObservableObject {

    // MARK: - Published state (main-thread only)

    @Published private(set) var level: Int = 0
    @Published private(set) var permissionDenied: Bool = false

    // MARK: - Configuration

    /// Offset added to 20·log₁₀(rms) to map dBFS to an approximate SPL-like range.
    /// At +90 dB, typical quiet-room background (~-30 dBFS) reads as ~60 dB.
    private static let calibrationOffset: Float = 90

    // MARK: - Private types

    private struct RawRMS {
        var value: Float = 0
    }

    // MARK: - Private state

    private var audioEngine: AVAudioEngine?
    private let rawLock = OSAllocatedUnfairLock(initialState: RawRMS())
    private var displayTimer: Timer?
    private var configChangeObserver: NSObjectProtocol?
    private var isRunning = false

    // MARK: - Public API

    func start() {
        guard !isRunning else { return }
        permissionDenied = false
        requestPermissionAndStart()
    }

    func stop() {
        guard isRunning else { return }
        tearDown()
    }

    // MARK: - Permission + engine lifecycle

    private func requestPermissionAndStart() {
        if #available(macOS 14, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                startEngine()
            case .denied:
                permissionDenied = true
            case .undetermined:
                AVAudioApplication.requestRecordPermission { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted { self?.startEngine() }
                        else       { self?.permissionDenied = true }
                    }
                }
            @unknown default:
                startEngine()
            }
        } else {
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                startEngine()
            case .denied, .restricted:
                permissionDenied = true
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted { self?.startEngine() }
                        else       { self?.permissionDenied = true }
                    }
                }
            @unknown default:
                startEngine()
            }
        }
    }

    private func startEngine() {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)

        guard format.sampleRate > 0 else { return }

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            return
        }

        audioEngine = engine
        isRunning = true
        permissionDenied = false

        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.tearDown()
            self?.startEngine()
        }

        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.updateDisplay()
        }
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    private func tearDown() {
        isRunning = false
        displayTimer?.invalidate()
        displayTimer = nil
        if let obs = configChangeObserver {
            NotificationCenter.default.removeObserver(obs)
            configChangeObserver = nil
        }
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        rawLock.withLock { $0 = RawRMS() }
        level = 0
    }

    // MARK: - Real-time callback (audio I/O thread — no main-thread work here)

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = vDSP_Length(buffer.frameLength)
        guard frameCount > 0 else { return }

        let channelCount = Int(buffer.format.channelCount)
        var totalRMS: Float = 0
        for ch in 0 ..< max(1, channelCount) {
            var chRMS: Float = 0
            vDSP_rmsqv(channelData[ch], 1, &chRMS, frameCount)
            totalRMS += chRMS
        }
        let rms = totalRMS / Float(max(1, channelCount))
        rawLock.withLock { $0 = RawRMS(value: rms) }
    }

    // MARK: - Main-thread display update (30 fps)

    private func updateDisplay() {
        let rms = rawLock.withLock { $0.value }
        let dbValue = 20 * log10(max(rms, 1e-9)) + Self.calibrationOffset
        level = max(0, min(140, Int(dbValue.rounded())))
    }

    // MARK: - deinit

    deinit {
        displayTimer?.invalidate()
        if let obs = configChangeObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
    }
}
