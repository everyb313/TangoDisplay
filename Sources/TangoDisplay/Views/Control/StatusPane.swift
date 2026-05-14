import SwiftUI
import TangoDisplayCore

struct StatusPane: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: AppSettings
    @Binding var showingOverride: Bool
    @State private var showDebugLog = false

    private var isLastTandaEnabled: Bool {
        guard !settings.lastTandaLabel.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        let all = appState.profileStore.allProfiles
        if let id = settings.activeProfileID, let p = all.first(where: { $0.id == id }) {
            return p.showLastTandaLabel
        }
        return AppearanceProfile.classic.showLastTandaLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Status row
            HStack(spacing: 8) {
                playerBadge
                displayBadge
                watchdogIndicator
                Spacer()
            }

            // Control buttons (including Last Tanda as 4th)
            HStack(spacing: 8) {
                Button { appState.pollNow() } label: {
                    Label("Force Poll (⌘⇧R)", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button { showingOverride = true } label: {
                    Label("Override… (⌘⇧O)", systemImage: "display")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button { appState.togglePaused() } label: {
                    Label(
                        appState.isDisplayPausedByUser ? "Unpause Display (⌘⇧P)" : "Pause Display (⌘⇧P)",
                        systemImage: appState.isDisplayPausedByUser ? "play" : "pause"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(appState.isDisplayPausedByUser ? .orange : nil)
                .frame(maxWidth: .infinity)

                Button { appState.activateLastTanda(!appState.isLastTandaActive) } label: {
                    Label("Last Tanda", systemImage: appState.isLastTandaActive ? "flag.fill" : "flag")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(appState.isLastTandaActive ? .red : nil)
                .disabled(!isLastTandaEnabled)
                .help(isLastTandaEnabled ? "" : "Set Last Tanda label in Appearance Settings to enable.")
                .frame(maxWidth: .infinity)
            }

            // Current track info card
            if let track = appState.displayState.currentTrack {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Current Track")
                        .font(.system(size: 13, weight: .semibold))
                    trackInfoRows(track: track)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5))
            } else {
                Text("No track playing")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // Debug log toggle
            DisclosureGroup(isExpanded: $showDebugLog) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(appState.debugLog.reversed(), id: \.self) { line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: 120)
                .background(ControlTheme.codeBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } label: {
                Text("Debug Log (\(appState.debugLog.count) entries)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ControlTheme.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var playerBadge: some View {
        let color: Color = switch appState.currentPlayerState {
        case .playing:    .green
        case .pauseArmed: .red
        case .paused:     .orange
        case .stopped:    .gray
        }
        let label: String = switch appState.currentPlayerState {
        case .playing:    "Playing"
        case .pauseArmed: "Pause Armed"
        case .paused:     "Player Paused"
        case .stopped:    "Idle"
        }
        return badge(label: label, color: color)
    }

    private var displayBadge: some View {
        let paused = appState.isDisplayPausedByUser
        let mode   = appState.displayState.mode
        let color: Color = paused ? .orange : (mode == .cortina ? .blue : mode == .override ? .purple : .green)
        let label: String = paused ? "Display Paused" : (mode == .cortina ? "Cortina" : mode == .override ? "Override" : "Display Live")
        return badge(label: label, color: color)
    }

    private func badge(label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var watchdogIndicator: some View {
        let color: Color = appState.watchdogActive ? .orange : .green
        let icon = appState.watchdogActive ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
        let label = appState.watchdogActive
            ? "\(appState.settings.selectedPlayer.displayName) unreachable"
            : (appState.settings.selectedPlayer == .swinsian ? "Listening" : "Polling OK")
        return HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func trackInfoRows(track: Track) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            infoRow("Title",  track.title)
            infoRow("Artist", track.artist)
            infoRow("Genre",  track.genre.isEmpty ? "(empty)" : track.genre)
            if let pos = appState.displayState.tandaPosition {
                infoRow("Tanda",
                    pos.total.map { "Track \(pos.current) of \($0)" } ?? "Track \(pos.current)")
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
                .frame(width: 52, alignment: .trailing)
            Text(value)
                .font(.system(size: 13))
                .lineLimit(1)
        }
    }
}
