import AppKit
import AVFoundation

/// Extracts the first embedded artwork image from a local audio file.
/// Returns nil for streaming tracks, files without artwork, or missing files.
/// Must be called on a background queue — `asset.metadata` blocks while loading.
func artworkFromAudioFile(_ posixPath: String) -> NSImage? {
    let path = posixPath.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !path.isEmpty else { return nil }
    let url = URL(fileURLWithPath: path)
    let asset = AVURLAsset(url: url)
    let items = AVMetadataItem.metadataItems(
        from: asset.metadata,
        filteredByIdentifier: .commonIdentifierArtwork
    )
    guard let data = items.first?.dataValue else { return nil }
    return NSImage(data: data)
}
