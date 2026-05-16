import SwiftUI

@main
struct TangoDisplayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var sparkleUpdater = SparkleUpdater()

    init() {
        // Wire the delegate's appState reference before applicationDidFinishLaunching fires.
        // The delegate adaptor is initialised before the App body runs, so this is safe.
    }

    var body: some Scene {
        // Control window — singleton (uses Window, not WindowGroup)
        Window("TangoDisplay", id: "control") {
            ControlView()
                .environmentObject(appState)
                .environmentObject(appState.settings)
                .environmentObject(sparkleUpdater)
                .onAppear {
                    // Pass appState to the delegate (cannot be done in init because
                    // @StateObject is not available until the first render)
                    appDelegate.appState = appState
                }
        }
        .defaultSize(width: 700, height: 540)
        .commands {
            CommandGroup(after: .help) {
                Button("Tango Display Website") {
                    NSWorkspace.shared.open(URL(string: "https://tangodisplay.com")!)
                }
                Button("Facebook Group") {
                    NSWorkspace.shared.open(URL(string: "https://www.facebook.com/groups/tangodisplay")!)
                }
            }
        }

        // Presentation window — WindowGroup allows dragging to external monitors
        WindowGroup(id: "presentation") {
            PresentationView()
                .environmentObject(appState)
                .environmentObject(appState.settings)
        }
        .defaultSize(width: 1280, height: 720)
    }
}
