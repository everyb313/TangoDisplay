import AVFoundation
import SwiftUI
import TangoDisplayCore

// MARK: - Settings section (embedded in PlayerSettingsView)

struct AudioUnitPluginSettingsSection: View {
    @ObservedObject var player: LocalPlayerSource
    @EnvironmentObject var settings: AppSettings
    @State private var showPicker = false
    @State private var showSavePresetAlert = false
    @State private var newPresetName = ""

    private var activePresetLabel: String {
        guard let id = player.activePresetID,
              let p = player.availablePresets.first(where: { $0.id == id }) else { return "None" }
        return p.name
    }

    var body: some View {
        Group {
            Toggle("Enable Audio Unit Plugin", isOn: Binding(
                get: { settings.audioUnitPluginEnabled },
                set: { enabled in
                    if enabled { player.enableAudioUnitPlugin() }
                    else       { player.disableAudioUnitPlugin() }
                }
            ))

            LabeledContent("Plugin") {
                HStack {
                    Text(settings.selectedAudioUnitPlugin.map { "\($0.name) · \($0.manufacturerName)" } ?? "None")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button("Choose…") { showPicker = true }
                }
            }

            Toggle("Bypass", isOn: Binding(
                get: { settings.audioUnitPluginBypassed },
                set: { player.bypassAudioUnitPlugin($0) }
            ))
            .disabled(!settings.audioUnitPluginEnabled || settings.selectedAudioUnitPlugin == nil)

            HStack(spacing: 12) {
                Button("Open Plugin Window") {
                    player.openPluginWindow()
                }
                .disabled(!player.audioUnitPluginStatus.isActive)

                Button("Remove", role: .destructive) {
                    player.removeAudioUnitPlugin()
                }
                .disabled(settings.selectedAudioUnitPlugin == nil)
            }

            if player.audioUnitPluginStatus.isActive {
                LabeledContent("Preset") {
                    HStack {
                        if !player.availablePresets.isEmpty {
                            let factoryPresets = player.availablePresets.filter(\.isFactory)
                            let userPresets = player.availablePresets.filter(\.isUser)
                            Menu {
                                if !factoryPresets.isEmpty {
                                    Section("Factory") {
                                        ForEach(factoryPresets) { p in
                                            Button(p.name) { player.applyPreset(p) }
                                        }
                                    }
                                }
                                if !userPresets.isEmpty {
                                    Section("Saved") {
                                        ForEach(userPresets) { p in
                                            Button(p.name) { player.applyPreset(p) }
                                        }
                                    }
                                    Divider()
                                    ForEach(userPresets) { p in
                                        Button("Delete \"\(p.name)\"", role: .destructive) {
                                            try? player.deletePreset(p)
                                        }
                                    }
                                }
                            } label: {
                                Text(activePresetLabel)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Button("Save as Preset…") {
                            newPresetName = ""
                            showSavePresetAlert = true
                        }
                    }
                }
                .alert("Save as Preset", isPresented: $showSavePresetAlert) {
                    TextField("Preset name", text: $newPresetName)
                    Button("Save") {
                        let name = newPresetName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        try? player.saveCurrentAsPreset(named: name)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Enter a name for the current EQ settings.")
                }
            }

            LabeledContent("Status") {
                Text(player.audioUnitPluginStatus.displayText)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Text("Advanced feature — test your plugin before using it live. If loading fails, Setlist continues without it.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .sheet(isPresented: $showPicker) {
            AudioUnitPluginPickerSheet { selection in
                player.selectAudioUnitPlugin(selection)
                showPicker = false
            }
        }
    }
}

// MARK: - Plugin picker sheet

struct AudioUnitPluginPickerSheet: View {
    var onSelect: (AudioUnitPluginSelection) -> Void

    @State private var plugins: [AudioUnitPluginSelection] = []
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose Audio Unit Plugin")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if isLoading {
                ProgressView("Scanning plugins…")
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if plugins.isEmpty {
                Text("No Audio Unit effect plugins found.")
                    .foregroundColor(.secondary)
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(plugins) { plugin in
                    Button {
                        onSelect(plugin)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plugin.name)
                                .font(.system(size: 13))
                            Text(plugin.manufacturerName)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(width: 380, height: 440)
        .task {
            let manager = AudioUnitPluginManager()
            plugins = manager.availableEffects()
            isLoading = false
        }
    }
}
