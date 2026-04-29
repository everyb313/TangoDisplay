import AppKit
import SwiftUI
import TangoDisplayCore
import UniformTypeIdentifiers

struct AppearanceSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: AppSettings

    private let availableFonts: [String] = ["System"] + NSFontManager.shared.availableFontFamilies.sorted()

    // Working copy — edits sync to appState.draftProfile for instant live reflection
    @State private var working: AppearanceProfile = .classic
    @State private var showingSaveSheet = false
    @State private var newProfileName = ""
    @State private var didSave = false
    @State private var savedWorking: AppearanceProfile = .classic
    @State private var bgThumbnail: NSImage? = nil

    private var workingIsBuiltIn: Bool { working.isBuiltIn }
    private var isDirty: Bool { working != savedWorking }

    var body: some View {
        Form {
            Section {
                Picker("Style", selection: $working.transitionStyle) {
                    ForEach(TransitionStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                HStack {
                    Text("Duration")
                    Slider(value: $working.transitionDuration, in: 0...2, step: 0.1)
                    Text(String(format: "%.1fs", working.transitionDuration))
                        .monospacedDigit()
                        .frame(width: 36)
                }
            } header: {
                Text("Transition")
                    .foregroundColor(ControlTheme.accent)
            }

            Section {
                colorRow("Background",    hex: $working.backgroundColor)
                colorRow("Artist",        hex: $working.artistColor)
                colorRow("Title",         hex: $working.titleColor)
                colorRow("Genre/label",   hex: $working.genreColor)
                colorRow("Year",          hex: $working.yearColor)
                colorRow("Singer",        hex: $working.singerColor)
                colorRow("Track counter", hex: $working.trackCounterColor)
            } header: {
                Text("Colors")
                    .foregroundColor(ControlTheme.accent)
            }

            Section {
                Toggle("Display album artwork where available", isOn: $working.showAlbumArtwork)

                if working.showAlbumArtwork {
                    HStack {
                        Text("Opacity")
                        Slider(value: $working.albumArtworkOpacity, in: 0...1)
                        Text(String(format: "%.0f%%", working.albumArtworkOpacity * 100))
                            .monospacedDigit()
                            .frame(width: 36)
                    }
                    HStack {
                        Text("Scale")
                        Slider(value: $working.albumArtworkScale, in: 0.1...5.0)
                        Text(String(format: "%.2f×", working.albumArtworkScale))
                            .monospacedDigit()
                            .frame(width: 44)
                    }
                    HStack {
                        Text("Horizontal")
                        Slider(value: $working.albumArtworkOffsetX, in: -2000...2000)
                        Text(String(format: "%+.0f", working.albumArtworkOffsetX))
                            .monospacedDigit()
                            .frame(width: 48)
                    }
                    HStack {
                        Text("Vertical")
                        Slider(value: $working.albumArtworkOffsetY, in: -2000...2000)
                        Text(String(format: "%+.0f", working.albumArtworkOffsetY))
                            .monospacedDigit()
                            .frame(width: 48)
                    }
                }
            } header: {
                Text("Album Artwork")
                    .foregroundColor(ControlTheme.accent)
            }

            Section {
                HStack(spacing: 12) {
                    // Thumbnail or placeholder
                    Group {
                        if let thumb = bgThumbnail {
                            Image(nsImage: thumb)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipped()
                                .cornerRadius(4)
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.secondary)
                                )
                        }
                    }
                    Spacer()
                    Button(working.backgroundImageFilename == nil ? "Pick Image…" : "Change Image…") {
                        pickImage()
                    }
                    .buttonStyle(.bordered)
                    if working.backgroundImageFilename != nil {
                        Button("Clear") { clearImage() }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                    }
                }

                if working.backgroundImageFilename != nil {
                    HStack {
                        Text("Opacity")
                        Slider(value: $working.backgroundImageOpacity, in: 0...1)
                        Text(String(format: "%.0f%%", working.backgroundImageOpacity * 100))
                            .monospacedDigit()
                            .frame(width: 36)
                    }
                    HStack {
                        Text("Scale")
                        Slider(value: $working.backgroundImageScale, in: 0.1...5.0)
                        Text(String(format: "%.2f×", working.backgroundImageScale))
                            .monospacedDigit()
                            .frame(width: 44)
                    }
                    HStack {
                        Text("Horizontal")
                        Slider(value: $working.backgroundImageOffsetX, in: -2000...2000)
                        Text(String(format: "%+.0f", working.backgroundImageOffsetX))
                            .monospacedDigit()
                            .frame(width: 48)
                    }
                    HStack {
                        Text("Vertical")
                        Slider(value: $working.backgroundImageOffsetY, in: -2000...2000)
                        Text(String(format: "%+.0f", working.backgroundImageOffsetY))
                            .monospacedDigit()
                            .frame(width: 48)
                    }
                }
            } header: {
                Text("Background Image")
                    .foregroundColor(ControlTheme.accent)
            }

            Section {
                fontRow("Artist", name: $working.artistFontName, size: $working.artistFontSize,
                        bold: $working.artistFontBold, italic: $working.artistFontItalic)
                fontRow("Title",  name: $working.titleFontName,  size: $working.titleFontSize,
                        bold: $working.titleFontBold,  italic: $working.titleFontItalic)
                fontRow("Genre",  name: $working.genreFontName,  size: $working.genreFontSize,
                        bold: $working.genreFontBold,  italic: $working.genreFontItalic)
                Toggle("Show Year", isOn: $working.showYear)
                if working.showYear {
                    fontRow("Year", name: $working.yearFontName, size: $working.yearFontSize,
                            bold: $working.yearFontBold, italic: $working.yearFontItalic)
                }
                Toggle("Include singer", isOn: $working.showSinger)
                if working.showSinger {
                    Picker("Source", selection: $working.singerSource) {
                        ForEach(SingerSource.allCases, id: \.self) { source in
                            Text(source.displayName).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
                    fontRow("Singer", name: $working.singerFontName, size: $working.singerFontSize,
                            bold: $working.singerFontBold, italic: $working.singerFontItalic)
                    Toggle("Show singer during cortina", isOn: $working.showSingerDuringCortina)
                }
            } header: {
                Text("Fonts")
                    .foregroundColor(ControlTheme.accent)
            }

            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dance Tracks")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                    orderRows(items: $working.danceItemOrder)
                }

                Divider()
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cortinas — Coming Up")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                    orderRows(items: $working.cortinaItemOrder)
                }
            } header: {
                Text("Text Order")
                    .foregroundColor(ControlTheme.accent)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Save as New Profile…") {
                        newProfileName = working.name
                        showingSaveSheet = true
                    }
                    .buttonStyle(.bordered)
                    Button("Save") { saveProfile() }
                        .buttonStyle(.borderedProminent)
                }
                if isDirty {
                    HStack {
                        Spacer()
                        Label("Unsaved changes", systemImage: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                    .transition(.opacity)
                }
                if didSave {
                    HStack {
                        Spacer()
                        Label("Saved!", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    .transition(.opacity)
                }
                if workingIsBuiltIn {
                    Text("Saving will create a new custom profile based on \(working.name).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            loadWorkingCopy()
            appState.draftProfile = working
        }
        .onDisappear {
            appState.draftProfile = nil
            appState.hasUnsavedAppearanceChanges = false
        }
        .onChange(of: appState.settings.activeProfileID) { _ in loadWorkingCopy() }
        .onChange(of: working) { _ in
            appState.draftProfile = working
            appState.hasUnsavedAppearanceChanges = isDirty
        }
        .sheet(isPresented: $showingSaveSheet) { saveSheet }
    }

    @ViewBuilder
    private func orderRows(items: Binding<[DisplayTextItem]>) -> some View {
        ForEach(items.wrappedValue.indices, id: \.self) { index in
            HStack {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                Text(items.wrappedValue[index].displayName)
                Spacer()
                Button {
                    items.wrappedValue.swapAt(index, index - 1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(index == 0)
                Button {
                    items.wrappedValue.swapAt(index, index + 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(index == items.wrappedValue.count - 1)
            }
        }
    }

    private func colorRow(_ label: String, hex: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            ColorPicker("", selection: Binding(
                get: { Color(hex: hex.wrappedValue) },
                set: { hex.wrappedValue = $0.hexString }
            ))
            .labelsHidden()
            .frame(width: 44)
        }
    }

    private func fontRow(_ label: String, name: Binding<String>, size: Binding<Double>,
                         bold: Binding<Bool>, italic: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .frame(width: 60, alignment: .leading)
            Picker("", selection: name) {
                ForEach(availableFonts, id: \.self) { family in
                    Text(family).tag(family)
                }
            }
            .labelsHidden()
            .frame(width: 180)
            Spacer()
            Stepper(value: size, in: 8...200, step: 2) {
                Text(String(format: "%.0fpt", size.wrappedValue))
                    .monospacedDigit()
                    .frame(width: 44)
            }
            Toggle("B", isOn: bold)
                .toggleStyle(.button)
                .font(.system(size: 12, weight: .bold))
                .help("Bold")
            Toggle("I", isOn: italic)
                .toggleStyle(.button)
                .font(.system(size: 12).italic())
                .help("Italic")
        }
    }

    private func loadWorkingCopy() {
        let all = appState.profileStore.allProfiles
        if let id = appState.settings.activeProfileID,
           let found = all.first(where: { $0.id == id }) {
            working = found
        } else {
            working = .classic
        }
        savedWorking = working
        appState.hasUnsavedAppearanceChanges = false
        // Keep draft in sync so the live display reflects the freshly loaded profile.
        // (The onChange(of: working) modifier only fires on changes, not the initial set.)
        appState.draftProfile = working
        reloadThumbnail()
    }

    private func reloadThumbnail() {
        guard let filename = working.backgroundImageFilename else { bgThumbnail = nil; return }
        let url = appState.profileStore.imageURL(for: filename)
        bgThumbnail = NSImage(contentsOf: url)
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a background image"
        guard panel.runModal() == .OK, let src = panel.url else { return }

        let ext = src.pathExtension.isEmpty ? "jpg" : src.pathExtension
        let filename = "\(working.id.uuidString).\(ext)"
        let dest = appState.profileStore.imageURL(for: filename)
        appState.profileStore.createImagesDirectoryIfNeeded()

        // Remove previous image if it's a different file
        if let old = working.backgroundImageFilename, old != filename {
            try? FileManager.default.removeItem(
                at: appState.profileStore.imageURL(for: old))
        }

        // Overwrite if same filename (profile already had an image)
        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: dest)
        }
        try? FileManager.default.copyItem(at: src, to: dest)

        working.backgroundImageFilename = filename
        bgThumbnail = NSImage(contentsOf: dest)
    }

    private func clearImage() {
        if let filename = working.backgroundImageFilename {
            try? FileManager.default.removeItem(
                at: appState.profileStore.imageURL(for: filename))
        }
        working.backgroundImageFilename = nil
        working.backgroundImageOpacity = 1.0
        working.backgroundImageScale = 1.0
        working.backgroundImageOffsetX = 0.0
        working.backgroundImageOffsetY = 0.0
        bgThumbnail = nil
    }

    private var saveSheet: some View {
        VStack(spacing: 16) {
            Text("Save Profile")
                .font(.headline)

            TextField("Profile name", text: $newProfileName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
                .onSubmit { saveNewProfile() }

            HStack {
                Button("Cancel") { showingSaveSheet = false }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape, modifiers: [])

                Button("Save") { saveNewProfile() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(minWidth: 320)
    }

    private func saveNewProfile() {
        let trimmed = newProfileName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var newProfile = working
        newProfile.id = UUID()
        newProfile.name = trimmed
        newProfile.isBuiltIn = false
        try? appState.profileStore.save(newProfile)
        appState.settings.activeProfileID = newProfile.id
        showingSaveSheet = false
    }

    private func saveProfile() {
        if workingIsBuiltIn {
            var copy = working
            copy.id = UUID()
            copy.isBuiltIn = false
            try? appState.profileStore.save(copy)
            appState.settings.activeProfileID = copy.id
            // activeProfileID change fires loadWorkingCopy() which resets savedWorking
        } else {
            try? appState.profileStore.save(working)
            savedWorking = working
            appState.hasUnsavedAppearanceChanges = false
            // Explicitly refresh draftProfile so the display picks up the change immediately
            appState.draftProfile = working
        }
        showSaveConfirmation()
    }

    private func showSaveConfirmation() {
        withAnimation { didSave = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { self.didSave = false }
        }
    }
}

// MARK: - Color hexString helper (SwiftUI → hex)

extension Color {
    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int((ns.redComponent   * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent  * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
