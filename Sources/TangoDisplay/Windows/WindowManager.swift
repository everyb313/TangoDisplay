import AppKit
import SwiftUI

/// Manages the presentation NSWindow.
/// The reference is captured by WindowAccessor when PresentationView appears.
final class WindowManager {

    // MARK: - Stored reference

    static weak var presentationWindow: NSWindow? {
        didSet {
            // Give the window a stable identifier so we can find it later
            presentationWindow?.identifier = NSUserInterfaceItemIdentifier("com.tangodisplay.presentation")
        }
    }

    // MARK: - Registration (called from WindowAccessor inside PresentationView)

    static func register(_ window: NSWindow) {
        // Same window re-registering (e.g. WindowAccessor.updateNSView).
        if presentationWindow === window { return }

        // A different presentation window already exists — this happens when macOS
        // state restoration brings one back and ControlView's ensureOpen() then
        // calls openWindow() before the restored window has registered. Close the
        // duplicate so there is only ever one Live Display window.
        if presentationWindow != nil {
            DispatchQueue.main.async { window.close() }
            return
        }

        presentationWindow = window
        window.delegate = CloseGuard.shared
    }

    // MARK: - Move to display

    /// Moves the presentation window to fill the screen with the given displayID.
    /// No-op if the window is currently in fullscreen (moving a fullscreen window
    /// causes undefined behaviour; the user should exit fullscreen first).
    static func moveTo(displayID: CGDirectDisplayID) {
        guard let window = presentationWindow else { return }
        guard !window.styleMask.contains(.fullScreen) else { return }

        guard let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == displayID
        }) else { return }

        window.setFrame(screen.visibleFrame, display: true, animate: true)
    }

    // MARK: - Fullscreen toggle

    static func toggleFullscreen() {
        guard let window = presentationWindow else { return }
        window.toggleFullScreen(nil)
    }

    // MARK: - Open presentation window if closed

    /// Opens the presentation window via SwiftUI's openWindow action.
    /// Must be called with an Environment openWindow value.
    static func ensureOpen(openWindow: OpenWindowAction) {
        if presentationWindow == nil ||
           (presentationWindow?.isVisible == false && presentationWindow?.isMiniaturized == false) {
            openWindow(id: "presentation")
        }
    }

    // MARK: - Show presentation window (for menu bar / dock)

    /// Deminiaturises and raises the presentation window.
    /// If the window has been deallocated, falls back to the stored SwiftUI reopen action.
    static func showPresentationWindow(appState: AppState) {
        if let window = presentationWindow {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            Task { @MainActor in
                appState.reopenPresentationWindow?()
            }
        }
    }

    // MARK: - Show control window (for menu bar)

    static func showControlWindow() {
        guard let window = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "control" ||
            $0.title == "TangoDisplay"
        }) else { return }
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}
