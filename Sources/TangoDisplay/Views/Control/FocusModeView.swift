import SwiftUI
import TangoDisplayCore

struct FocusModeView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("focusModeSplitFraction") private var splitFraction: Double = 0.35
    @AppStorage("focusModeShowControls") private var showControls: Bool = true

    var body: some View {
        GeometryReader { geo in
            let minFrac = 160.0 / Double(geo.size.height)
            let maxFrac = max(minFrac, 1.0 - 120.0 / Double(geo.size.height))
            let clamped = max(minFrac, min(maxFrac, splitFraction))
            let topH = CGFloat(clamped) * geo.size.height

            VStack(spacing: 0) {
                topPane
                    .frame(maxWidth: .infinity)
                    .frame(height: topH)

                FocusDivider { delta in
                    let liveTopH = CGFloat(max(minFrac, min(maxFrac, splitFraction))) * geo.size.height
                    let newFrac = Double(liveTopH + delta) / Double(geo.size.height)
                    splitFraction = max(minFrac, min(maxFrac, newFrac))
                }

                setlistContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .toolbar {
            ToolbarItem {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showControls.toggle() }
                } label: {
                    Label(
                        showControls ? "Hide Controls" : "Show Controls",
                        systemImage: "rectangle.righthalf.inset.filled"
                    )
                }
                .help(showControls ? "Hide display controls" : "Show display controls")
            }
        }
    }

    private var topPane: some View {
        HStack(spacing: 0) {
            PreviewPane()
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showControls {
                Divider()
                FocusControlsPanel()
                    .frame(width: 200)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showControls)
        .clipped()
    }

    @ViewBuilder
    private var setlistContent: some View {
        if let lp = appState.localPlayer {
            SetlistView(setlist: appState.setlist, player: lp)
                .environmentObject(appState)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "list.number")
                    .font(.system(size: 44))
                    .foregroundColor(.secondary)
                Text("Switch to Built-in Player to use the setlist")
                    .foregroundColor(.secondary)
                Button("Switch to Built-in Player") {
                    appState.settings.selectedPlayer = .builtIn
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Controls panel

private struct FocusControlsPanel: View {
    @EnvironmentObject var appState: AppState

    private var isLastTandaEnabled: Bool {
        guard !appState.settings.lastTandaLabel.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        let all = appState.profileStore.allProfiles
        if let id = appState.settings.activeProfileID, let p = all.first(where: { $0.id == id }) {
            return p.showLastTandaLabel
        }
        return AppearanceProfile.classic.showLastTandaLabel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DISPLAY CONTROLS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.bottom, 2)

            Button { appState.pollNow() } label: {
                Label("Force Poll", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(maxWidth: .infinity)

            Button {
                NotificationCenter.default.post(name: .showOverrideDialog, object: nil)
            } label: {
                Label("Override…", systemImage: "display")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(maxWidth: .infinity)

            Button { appState.togglePaused() } label: {
                Label(
                    appState.isDisplayPausedByUser ? "Unpause Display" : "Pause Display",
                    systemImage: appState.isDisplayPausedByUser ? "play" : "pause"
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(appState.isDisplayPausedByUser ? .orange : nil)
            .frame(maxWidth: .infinity)

            Button { appState.activateLastTanda(!appState.isLastTandaActive) } label: {
                Label("Last Tanda", systemImage: appState.isLastTandaActive ? "flag.fill" : "flag")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(appState.isLastTandaActive ? .red : nil)
            .disabled(!isLastTandaEnabled)
            .help(isLastTandaEnabled ? "" : "Set Last Tanda label in Appearance Settings to enable.")
            .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(12)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Custom drag divider

private struct FocusDivider: View {
    let onDrag: (CGFloat) -> Void

    var body: some View {
        FocusDividerRepresentable(onDrag: onDrag)
            .frame(maxWidth: .infinity)
            .frame(height: 8)
    }
}

private struct FocusDividerRepresentable: NSViewRepresentable {
    let onDrag: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDrag: onDrag) }

    func makeNSView(context: Context) -> FocusDividerNSView {
        FocusDividerNSView(coordinator: context.coordinator)
    }

    func updateNSView(_ nsView: FocusDividerNSView, context: Context) {
        context.coordinator.onDrag = onDrag
    }

    final class Coordinator {
        var onDrag: (CGFloat) -> Void
        init(onDrag: @escaping (CGFloat) -> Void) { self.onDrag = onDrag }
    }
}

private final class FocusDividerNSView: NSView {
    var coordinator: FocusDividerRepresentable.Coordinator
    private var startY: CGFloat = 0

    init(coordinator: FocusDividerRepresentable.Coordinator) {
        self.coordinator = coordinator
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.separatorColor.setFill()
        dirtyRect.fill()

        let gripW: CGFloat = 32
        let gripH: CGFloat = 3
        let gripRect = CGRect(
            x: (bounds.width - gripW) / 2,
            y: (bounds.height - gripH) / 2,
            width: gripW,
            height: gripH
        )
        NSColor.secondaryLabelColor.withAlphaComponent(0.5).setFill()
        NSBezierPath(roundedRect: gripRect, xRadius: 1.5, yRadius: 1.5).fill()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeUpDown)
    }

    override func mouseDown(with event: NSEvent) {
        startY = event.locationInWindow.y
    }

    override func mouseDragged(with event: NSEvent) {
        let y = event.locationInWindow.y
        coordinator.onDrag(startY - y)  // positive delta = dragged down = top pane grows
        startY = y
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
