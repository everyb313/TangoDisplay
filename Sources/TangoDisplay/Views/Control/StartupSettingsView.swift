import SwiftUI

struct StartupSettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("Startup Mode", selection: $settings.startupMode) {
                    ForEach(StartupMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Text(startupModeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Startup Mode")
                    .foregroundColor(ControlTheme.accent)
            }

            Section {
                Toggle("Hide Left Menu Bar on Startup",
                       isOn: $settings.hideLeftMenuBarOnStartup)
                Text("The left navigation menu starts collapsed. You can expand it at any time.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Navigation")
                    .foregroundColor(ControlTheme.accent)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var startupModeDescription: String {
        switch settings.startupMode {
        case .fullExperience:
            return "Live Display and Settings windows both open at launch."
        case .playerFocused:
            return "Settings window is focused at launch; Live Display starts minimised to the Dock. Restore it any time from the menu bar icon or Dock."
        }
    }
}
