import SwiftUI
import TangoDisplayCore

struct StatusPane: View {
    @EnvironmentObject var appState: AppState
    @Binding var showingOverride: Bool
    @State private var showDebugLog = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Status row
            HStack(spacing: 8) {
                playerBadge
                displayBadge
                watchdogIndicator
                Spacer()
            }

            // Control buttons
            HStack(spacing: 8) {
                Button("Force Poll (⌘⇧R)") { appState.pollNow() }
                    .buttonStyle(.bordered)

                Button("Override… (⌘⇧O)") { showingOverride = true }
                    .buttonStyle(.bordered)

                Button(appState.isDisplayPausedByUser ? "Unpause Display (⌘⇧P)" : "Pause Display (⌘⇧P)") {
                    appState.togglePaused()
                }
                .buttonStyle(.bordered)
                .tint(appState.isDisplayPausedByUser ? .orange : nil)
            }

            Divider()

            // Current track info
            if let track = appState.displayState.currentTrack {
                trackInfoRows(track: track)
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
        .padding()
    }

    private var playerBadge: some View {
        let color: Color = switch appState.currentPlayerState {
        case .playing: .green
        case .paused:  .orange
        case .stopped: .gray
        }
        let label: String = switch appState.currentPlayerState {
        case .playing: "Playing"
        case .paused:  "Player Paused"
        case .stopped: "Idle"
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
        HStack(spacing: 5) {
            Image(systemName: appState.watchdogActive ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(appState.watchdogActive ? .orange : .green)
                .font(.system(size: 12))
            Text(appState.watchdogActive
                ? "\(appState.settings.selectedPlayer.displayName) unreachable"
                : (appState.settings.selectedPlayer == .swinsian ? "Listening" : "Polling OK"))
                .font(.system(size: 12))
                .foregroundColor(appState.watchdogActive ? .orange : .secondary)
        }
    }

    private func trackInfoRows(track: Track) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
        HStack(alignment: .top, spacing: 6) {
            Text(label + ":")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 48, alignment: .trailing)
            Text(value)
                .font(.system(size: 12))
                .lineLimit(1)
        }
    }
}
