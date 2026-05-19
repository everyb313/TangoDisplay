import SwiftUI
import TangoDisplayCore

struct PlayerSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: AppSettings

    @State private var jriverZones: [JRiverZone] = []
    @State private var isLoadingZones = false
    @State private var pendingPlayerChoice: MusicPlayerChoice? = nil
    @State private var showClearSetlistAlert = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(MusicPlayerChoice.allCases) { choice in
                        HStack(spacing: 6) {
                            Image(systemName: settings.selectedPlayer == choice
                                  ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(settings.selectedPlayer == choice
                                                 ? Color.accentColor : Color.secondary)
                                .font(.system(size: 13))
                            Text(choice.displayName)
                            if choice == .builtIn {
                                Text("Recommended")
                                    .font(.system(size: 10))
                                    .foregroundColor(.accentColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let newChoice = choice
                            guard newChoice != settings.selectedPlayer else { return }
                            if settings.selectedPlayer == .builtIn && !appState.setlist.entries.isEmpty {
                                pendingPlayerChoice = newChoice
                                showClearSetlistAlert = true
                            } else {
                                settings.selectedPlayer = newChoice
                            }
                        }
                    }
                }
                .alert("Clear Setlist?", isPresented: $showClearSetlistAlert) {
                    Button("Switch Player", role: .destructive) {
                        if let choice = pendingPlayerChoice {
                            appState.setlist.clear()
                            settings.selectedPlayer = choice
                        }
                        pendingPlayerChoice = nil
                    }
                    Button("Cancel", role: .cancel) {
                        pendingPlayerChoice = nil
                    }
                } message: {
                    Text("Switching to a different player will remove all tracks from the setlist.")
                }
            } header: {
                Text("Player Source")
                    .foregroundColor(ControlTheme.accent)
            }

            Section {
                playerStatusInfo
            } header: {
                Text("Notes")
                    .foregroundColor(ControlTheme.accent)
            }

            if settings.selectedPlayer == .jriver {
                Section {
                    LabeledContent("Zone:") {
                        HStack(spacing: 8) {
                            Picker("", selection: $settings.jriverZoneID) {
                                Text("Active (follows current)").tag(-1)
                                ForEach(jriverZones) { zone in
                                    Text(zone.name).tag(zone.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .fixedSize()
                            Button(isLoadingZones ? "Loading…" : "Refresh") {
                                loadJRiverZones()
                            }
                            .disabled(isLoadingZones)
                        }
                    }
                    Text("Pin TangoDisplay to a specific zone so pre-listening in another zone never affects the display.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Zone")
                        .foregroundColor(ControlTheme.accent)
                }
                .onAppear { if jriverZones.isEmpty { loadJRiverZones() } }
            }

            if settings.selectedPlayer == .builtIn, let localPlayer = appState.localPlayer {
                Section {
                    LabeledContent("Main output:") {
                        Picker("", selection: $settings.builtInOutputDeviceUID) {
                            Text("System Default").tag("")
                            ForEach(appState.availableAudioOutputDevices) { device in
                                Text(device.name).tag(device.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                } header: {
                    Text("Built-in Player")
                        .foregroundColor(ControlTheme.accent)
                }

                Section {
                    LabeledContent("Cortina fade") {
                        HStack(spacing: 8) {
                            Slider(value: $settings.builtInFadeDuration, in: 1...15, step: 0.5)
                            Text("\(settings.builtInFadeDuration, specifier: "%.1f")s")
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                    Text("Duration of the volume fade when using Fade & Stop or Fade & Continue.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Toggle("Auto-fade all cortinas", isOn: $settings.autoFadeCortinasEnabled)
                    if settings.autoFadeCortinasEnabled {
                        LabeledContent("Cortina play time") {
                            HStack(spacing: 8) {
                                Slider(value: $settings.cortinaPlayTime, in: 5...120, step: 1)
                                Text("\(Int(settings.cortinaPlayTime))s")
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                        Text("Warning – auto-fade applies to cortinas. Your library and cortina rules must ensure correct tagging to avoid dance tracks having auto-fade applied.")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    Text("Cortinas")
                        .foregroundColor(ControlTheme.accent)
                }

                Section {
                    LabeledContent("Mark as played") {
                        Picker("", selection: $settings.markAsPlayedAfterCompletion) {
                            Text("After song ends").tag(true)
                            Text("After...").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                    if !settings.markAsPlayedAfterCompletion {
                        LabeledContent("") {
                            HStack(spacing: 8) {
                                Slider(
                                    value: Binding(
                                        get: { Double(settings.markAsPlayedAfterSeconds) },
                                        set: { settings.markAsPlayedAfterSeconds = Int($0.rounded()) }
                                    ),
                                    in: 1...30,
                                    step: 1
                                )
                                Text("\(settings.markAsPlayedAfterSeconds)s")
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                    Text("Controls when a track is marked as played. Once marked, resuming playback skips to the next track.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Toggle("Duplicate track protection", isOn: $settings.duplicateTrackProtection)
                    Text("Warns before adding a track that is already in the setlist.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Playback")
                        .foregroundColor(ControlTheme.accent)
                }

                Section {
                    Toggle("Auto-gap", isOn: $settings.autoGapEnabled)
                    if settings.autoGapEnabled {
                        LabeledContent("Minimum gap") {
                            HStack(spacing: 8) {
                                Slider(value: $settings.autoGapDuration, in: 0.5...5, step: 0.5)
                                Text("\(settings.autoGapDuration, specifier: "%.1f")s")
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                        Toggle("Skip gap before first track", isOn: $settings.autoGapIgnoreFirstTrack)
                        Text("The first track in the setlist starts immediately with no silence preroll.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("Analyzes silence at track boundaries and adds padding so the gap between tracks meets the minimum. Only adds silence, never removes it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Gap")
                        .foregroundColor(ControlTheme.accent)
                }

                Section {
                    ReplayGainModePicker(mode: $settings.replayGainMode)
                    Toggle("Prevent clipping", isOn: $settings.replayGainPreventClipping)
                    LabeledContent("Preamp") {
                        HStack(spacing: 8) {
                            Slider(value: $settings.replayGainPreampDb, in: -12...6, step: 0.5)
                            Text(String(format: "%+.1f dB", settings.replayGainPreampDb))
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 56, alignment: .trailing)
                        }
                    }
                    .disabled(settings.replayGainMode == .off)
                    LabeledContent("Target Loudness") {
                        HStack(spacing: 8) {
                            Slider(value: $settings.replayGainTargetLufs, in: -23...(-14), step: 0.5)
                            Text(String(format: "%.1f LUFS", settings.replayGainTargetLufs))
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 72, alignment: .trailing)
                        }
                    }
                    .disabled(settings.replayGainMode != .auto)
                    Text("ReplayGain adjusts playback volume using loudness metadata stored in the audio file. Auto mode uses metadata when available; when absent it analyses the file and calculates a gain against the target loudness.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("ReplayGain")
                        .foregroundColor(ControlTheme.accent)
                }

                AudioUnitPluginSettingsSection(player: localPlayer)

                Section {
                    Toggle("Title", isOn: .constant(true)).disabled(true)
                    Toggle("Artist", isOn: .constant(true)).disabled(true)
                    Toggle("Genre", isOn: .constant(true)).disabled(true)
                    Toggle("Year", isOn: $settings.showYear)
                    Toggle("Time", isOn: $settings.showTime)
                    Toggle("Comments", isOn: $settings.showComments)
                    Toggle("Album Artist", isOn: $settings.showAlbumArtist)
                    Text("Controls which fields are shown in the setlist rows.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Track Info")
                        .foregroundColor(ControlTheme.accent)
                }

                Section {
                    Toggle("Genre tag colours", isOn: $settings.genreColorsEnabled)
                    Text("Colour upcoming (unplayed) tracks by genre keyword. Keywords are case-insensitive and match anywhere in the genre name. Playing, paused, and already-played tracks are unaffected.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if settings.genreColorsEnabled {
                        Toggle("Include song title", isOn: $settings.genreColorTitleEnabled)
                        GenreColourRulesEditor(rules: $settings.genreColorRules)
                    }
                } header: {
                    Text("Genre Colours")
                        .foregroundColor(ControlTheme.accent)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { appState.refreshAudioOutputDeviceList() }
    }

    private func loadJRiverZones() {
        isLoadingZones = true
        JRiverPoller.fetchZones { zones in
            jriverZones = zones
            isLoadingZones = false
        }
    }

    @ViewBuilder
    private var playerStatusInfo: some View {
        switch settings.selectedPlayer {
        case .musicApp:
            Label {
                Text("Polls Music.app every 2 seconds via AppleScript. Playlist look-ahead and tanda counting are fully supported.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }

        case .swinsian:
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("Listens for Swinsian push notifications in real time. Upcoming tanda look-ahead is supported when playing from a queue or playlist.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                Label {
                    Text("Track counter shows position within the current tanda (e.g. Track 2). The total (e.g. of 4) is unavailable — Swinsian's queue starts at the current track so backwards context is unavailable.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
            }

        case .embrace:
            Label {
                Text("Listens for Embrace notifications and polls via AppleScript in real time. Playlist look-ahead and tanda counting are fully supported.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }

        case .jriver:
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("Polls JRiver Media Center every 2 seconds via its MCWS HTTP API. Playlist look-ahead and tanda counting are fully supported.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                Label {
                    Text("JRiver must be running with Media Network enabled (Tools → Options → Media Network). Connects to 127.0.0.1 on the default MCWS port.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
                Label {
                    Text("If you use multiple zones (e.g. Player + Prelistening), use the Zone picker below to pin TangoDisplay to a specific zone.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
            }

        case .builtIn:
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("TangoDisplay plays audio directly. Build your setlist in the Setlist tab by dragging tracks from Music.app, Swinsian, or Finder.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                Label {
                    Text("Fully integrated support.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
        }
    }
}
