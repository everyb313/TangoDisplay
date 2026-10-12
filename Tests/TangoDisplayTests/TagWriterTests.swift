import AVFoundation
import Foundation
import TangoDisplayCore
import TangoDisplayObjC

// Proves TagLib linked, and that what it writes is what AVFoundation — and so
// SetlistManager.readMetadata — reads back. AIFF exercises the ID3v2 path (incl. the
// GROUPING → TIT1 mirror), M4A the MP4 atom path.
func runTagWriterTests() {
    suite("Tag writer (TagLib)") {
        for ext in ["aiff", "m4a"] {
            test("\(ext): written tags read back through AVFoundation") {
                let url = try makeSilentFile(ext: ext)
                defer { try? FileManager.default.removeItem(at: url) }

                var err: NSString?
                let ok = TDWriteTags(url.path, ["TITLE": "Poema", "ARTIST": "Francisco Canaro",
                                                "GENRE": "Tango", "GROUPING": "Roberto Maida"], &err)
                try expect(ok, "write failed: \(err ?? "")")

                let items = AVURLAsset(url: url).metadata
                func value(_ id: AVMetadataIdentifier) -> String? {
                    AVMetadataItem.metadataItems(from: items, filteredByIdentifier: id).first?.stringValue
                }
                let common = { (key: AVMetadataKey) in
                    AVMetadataItem.metadataItems(from: items, withKey: key, keySpace: .common).first?.stringValue
                }
                try expectEqual(common(.commonKeyTitle), "Poema")
                try expectEqual(common(.commonKeyArtist), "Francisco Canaro")
                let grouping = ext == "m4a" ? groupingAtom(items)?.stringValue
                                            : value(.id3MetadataContentGroupDescription)
                try expectEqual(grouping, "Roberto Maida")

                // Empty value removes the field; untouched keys survive.
                try expect(TDWriteTags(url.path, ["GROUPING": ""], &err))
                let after = AVURLAsset(url: url).metadata
                try expect(AVMetadataItem.metadataItems(from: after, withKey: AVMetadataKey.commonKeyTitle,
                                                        keySpace: .common).first?.stringValue == "Poema")
                let gone = ext == "m4a" ? groupingAtom(after) == nil
                    : AVMetadataItem.metadataItems(from: after, filteredByIdentifier: .id3MetadataContentGroupDescription).isEmpty
                try expect(gone, "grouping not removed")
            }
        }
    }
}

// TagLib writes ©grp the way old iTunes did — AVFoundation surfaces it under a packed
// NSNumber key, not .iTunesMetadataGrouping. readMetadata's string(forITunesAtom:) covers it.
private func groupingAtom(_ items: [AVMetadataItem]) -> AVMetadataItem? {
    items.first { ($0.key as? NSNumber)?.uint32Value == 0xA9_67_72_70 && $0.keySpace == .iTunes }
        ?? AVMetadataItem.metadataItems(from: items, filteredByIdentifier: .iTunesMetadataGrouping).first
}

private func makeSilentFile(ext: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("tagwriter-\(UUID().uuidString).\(ext)")
    let settings: [String: Any] = ext == "m4a"
        ? [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 2]
        : [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 2,
           AVLinearPCMBitDepthKey: 16, AVLinearPCMIsBigEndianKey: true, AVLinearPCMIsFloatKey: false]
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
    buffer.frameLength = 44100
    do {
        let file = try AVAudioFile(forWriting: url, settings: settings)
        try file.write(from: buffer)
    }   // file closes when it goes out of scope
    return url
}
