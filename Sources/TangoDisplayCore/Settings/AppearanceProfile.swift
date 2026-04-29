import Foundation

public struct AppearanceProfile: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var isBuiltIn: Bool

    public var titleFontName: String
    public var titleFontSize: Double
    public var titleFontBold: Bool
    public var titleFontItalic: Bool
    public var artistFontName: String
    public var artistFontSize: Double
    public var artistFontBold: Bool
    public var artistFontItalic: Bool
    public var genreFontName: String
    public var genreFontSize: Double
    public var genreFontBold: Bool
    public var genreFontItalic: Bool
    public var showYear: Bool
    public var yearFontName: String
    public var yearFontSize: Double
    public var yearFontBold: Bool
    public var yearFontItalic: Bool

    public var backgroundColor: String
    public var titleColor: String
    public var artistColor: String
    public var genreColor: String
    public var yearColor: String
    public var trackCounterColor: String

    public var transitionStyle: TransitionStyle
    public var transitionDuration: Double

    // Background image (optional — nil means no image)
    public var backgroundImageFilename: String?  // "{profileUUID}.{ext}" stored in images dir
    public var backgroundImageOpacity: Double    // 0.0–1.0
    public var backgroundImageScale: Double      // multiplier, 1.0 = fill screen
    public var backgroundImageOffsetX: Double    // points, horizontal pan
    public var backgroundImageOffsetY: Double    // points, vertical pan

    // Album artwork overlay (shown above background, below text; hidden during cortinas)
    public var showAlbumArtwork: Bool
    public var albumArtworkOpacity: Double   // 0.0–1.0
    public var albumArtworkScale: Double     // multiplier, 1.0 = natural size scaled to fit
    public var albumArtworkOffsetX: Double   // points, horizontal pan
    public var albumArtworkOffsetY: Double   // points, vertical pan

    // Configurable vertical order of text items on the display
    public var danceItemOrder: [DisplayTextItem]   // order for dance track display
    public var cortinaItemOrder: [DisplayTextItem] // order for cortina "coming up" section

    // Singer line (displays a track metadata field below the title)
    public var showSinger: Bool
    public var singerSource: SingerSource
    public var showSingerDuringCortina: Bool
    public var singerFontName: String
    public var singerFontSize: Double
    public var singerFontBold: Bool
    public var singerFontItalic: Bool
    public var singerColor: String

    public init(id: UUID, name: String, isBuiltIn: Bool,
                titleFontName: String = "System", titleFontSize: Double = 72,
                titleFontBold: Bool = true, titleFontItalic: Bool = false,
                artistFontName: String = "System", artistFontSize: Double = 96,
                artistFontBold: Bool = false, artistFontItalic: Bool = false,
                genreFontName: String = "System", genreFontSize: Double = 36,
                genreFontBold: Bool = false, genreFontItalic: Bool = false,
                showYear: Bool = false,
                yearFontName: String = "System", yearFontSize: Double = 36,
                yearFontBold: Bool = false, yearFontItalic: Bool = false,
                backgroundColor: String = "#000000",
                titleColor: String = "#FFFFFF",
                artistColor: String = "#FFFFFF",
                genreColor: String = "#AAAAAA",
                yearColor: String = "#AAAAAA",
                trackCounterColor: String = "#AAAAAA",
                transitionStyle: TransitionStyle = .fade,
                transitionDuration: Double = 0.4,
                backgroundImageFilename: String? = nil,
                backgroundImageOpacity: Double = 1.0,
                backgroundImageScale: Double = 1.0,
                backgroundImageOffsetX: Double = 0.0,
                backgroundImageOffsetY: Double = 0.0,
                showAlbumArtwork: Bool = false,
                albumArtworkOpacity: Double = 1.0,
                albumArtworkScale: Double = 1.0,
                albumArtworkOffsetX: Double = 0.0,
                albumArtworkOffsetY: Double = 0.0,
                danceItemOrder: [DisplayTextItem] = [.genre, .artist, .year, .title, .singer],
                cortinaItemOrder: [DisplayTextItem] = [.genre, .artist, .year, .singer],
                showSinger: Bool = false,
                singerSource: SingerSource = .comments,
                showSingerDuringCortina: Bool = false,
                singerFontName: String = "System",
                singerFontSize: Double = 48,
                singerFontBold: Bool = false,
                singerFontItalic: Bool = false,
                singerColor: String = "#AAAAAA") {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.titleFontName = titleFontName
        self.titleFontSize = titleFontSize
        self.titleFontBold = titleFontBold
        self.titleFontItalic = titleFontItalic
        self.artistFontName = artistFontName
        self.artistFontSize = artistFontSize
        self.artistFontBold = artistFontBold
        self.artistFontItalic = artistFontItalic
        self.genreFontName = genreFontName
        self.genreFontSize = genreFontSize
        self.genreFontBold = genreFontBold
        self.genreFontItalic = genreFontItalic
        self.showYear = showYear
        self.yearFontName = yearFontName
        self.yearFontSize = yearFontSize
        self.yearFontBold = yearFontBold
        self.yearFontItalic = yearFontItalic
        self.backgroundColor = backgroundColor
        self.titleColor = titleColor
        self.artistColor = artistColor
        self.genreColor = genreColor
        self.yearColor = yearColor
        self.trackCounterColor = trackCounterColor
        self.transitionStyle = transitionStyle
        self.transitionDuration = transitionDuration
        self.backgroundImageFilename = backgroundImageFilename
        self.backgroundImageOpacity = backgroundImageOpacity
        self.backgroundImageScale = backgroundImageScale
        self.backgroundImageOffsetX = backgroundImageOffsetX
        self.backgroundImageOffsetY = backgroundImageOffsetY
        self.showAlbumArtwork = showAlbumArtwork
        self.albumArtworkOpacity = albumArtworkOpacity
        self.albumArtworkScale = albumArtworkScale
        self.albumArtworkOffsetX = albumArtworkOffsetX
        self.albumArtworkOffsetY = albumArtworkOffsetY
        self.danceItemOrder = danceItemOrder
        self.cortinaItemOrder = cortinaItemOrder
        self.showSinger = showSinger
        self.singerSource = singerSource
        self.showSingerDuringCortina = showSingerDuringCortina
        self.singerFontName = singerFontName
        self.singerFontSize = singerFontSize
        self.singerFontBold = singerFontBold
        self.singerFontItalic = singerFontItalic
        self.singerColor = singerColor
    }

    // Custom decoder so existing JSON lacking the image keys still loads cleanly.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                   = try c.decode(UUID.self,            forKey: .id)
        name                 = try c.decode(String.self,          forKey: .name)
        isBuiltIn            = try c.decode(Bool.self,            forKey: .isBuiltIn)
        titleFontName        = try c.decode(String.self,          forKey: .titleFontName)
        titleFontSize        = try c.decode(Double.self,          forKey: .titleFontSize)
        titleFontBold        = try c.decodeIfPresent(Bool.self,    forKey: .titleFontBold)    ?? false
        titleFontItalic      = try c.decodeIfPresent(Bool.self,    forKey: .titleFontItalic)   ?? false
        artistFontName       = try c.decode(String.self,           forKey: .artistFontName)
        artistFontSize       = try c.decode(Double.self,           forKey: .artistFontSize)
        artistFontBold       = try c.decodeIfPresent(Bool.self,    forKey: .artistFontBold)    ?? false
        artistFontItalic     = try c.decodeIfPresent(Bool.self,    forKey: .artistFontItalic)  ?? false
        genreFontName        = try c.decode(String.self,           forKey: .genreFontName)
        genreFontSize        = try c.decode(Double.self,           forKey: .genreFontSize)
        genreFontBold        = try c.decodeIfPresent(Bool.self,    forKey: .genreFontBold)     ?? false
        genreFontItalic      = try c.decodeIfPresent(Bool.self,    forKey: .genreFontItalic)   ?? false
        showYear             = try c.decodeIfPresent(Bool.self,    forKey: .showYear)          ?? false
        yearFontName         = try c.decodeIfPresent(String.self,  forKey: .yearFontName)      ?? "System"
        yearFontSize         = try c.decodeIfPresent(Double.self,  forKey: .yearFontSize)      ?? 36
        yearFontBold         = try c.decodeIfPresent(Bool.self,    forKey: .yearFontBold)      ?? false
        yearFontItalic       = try c.decodeIfPresent(Bool.self,    forKey: .yearFontItalic)    ?? false
        backgroundColor      = try c.decode(String.self,          forKey: .backgroundColor)
        titleColor           = try c.decode(String.self,          forKey: .titleColor)
        artistColor          = try c.decode(String.self,          forKey: .artistColor)
        genreColor           = try c.decode(String.self,          forKey: .genreColor)
        yearColor            = try c.decodeIfPresent(String.self,  forKey: .yearColor)         ?? "#AAAAAA"
        trackCounterColor    = try c.decodeIfPresent(String.self, forKey: .trackCounterColor) ?? "#AAAAAA"
        transitionStyle      = try c.decode(TransitionStyle.self, forKey: .transitionStyle)
        transitionDuration   = try c.decode(Double.self,          forKey: .transitionDuration)
        // New fields — absent in older JSON files, fall back to defaults
        backgroundImageFilename = try c.decodeIfPresent(String.self,  forKey: .backgroundImageFilename)
        backgroundImageOpacity  = try c.decodeIfPresent(Double.self,  forKey: .backgroundImageOpacity)  ?? 1.0
        backgroundImageScale    = try c.decodeIfPresent(Double.self,  forKey: .backgroundImageScale)    ?? 1.0
        backgroundImageOffsetX  = try c.decodeIfPresent(Double.self,  forKey: .backgroundImageOffsetX)  ?? 0.0
        backgroundImageOffsetY  = try c.decodeIfPresent(Double.self,  forKey: .backgroundImageOffsetY)  ?? 0.0
        showAlbumArtwork        = try c.decodeIfPresent(Bool.self,    forKey: .showAlbumArtwork)        ?? false
        albumArtworkOpacity     = try c.decodeIfPresent(Double.self,  forKey: .albumArtworkOpacity)     ?? 1.0
        albumArtworkScale       = try c.decodeIfPresent(Double.self,  forKey: .albumArtworkScale)       ?? 1.0
        albumArtworkOffsetX     = try c.decodeIfPresent(Double.self,  forKey: .albumArtworkOffsetX)     ?? 0.0
        albumArtworkOffsetY     = try c.decodeIfPresent(Double.self,  forKey: .albumArtworkOffsetY)     ?? 0.0
        showSinger              = try c.decodeIfPresent(Bool.self,         forKey: .showSinger)              ?? false
        singerSource            = try c.decodeIfPresent(SingerSource.self, forKey: .singerSource)            ?? .comments
        showSingerDuringCortina = try c.decodeIfPresent(Bool.self,         forKey: .showSingerDuringCortina) ?? false
        singerFontName          = try c.decodeIfPresent(String.self,  forKey: .singerFontName)          ?? "System"
        singerFontSize          = try c.decodeIfPresent(Double.self,  forKey: .singerFontSize)          ?? 48
        singerFontBold          = try c.decodeIfPresent(Bool.self,    forKey: .singerFontBold)          ?? false
        singerFontItalic        = try c.decodeIfPresent(Bool.self,    forKey: .singerFontItalic)        ?? false
        singerColor             = try c.decodeIfPresent(String.self,  forKey: .singerColor)             ?? "#AAAAAA"
        danceItemOrder   = try c.decodeIfPresent([DisplayTextItem].self, forKey: .danceItemOrder)   ?? [.genre, .artist, .year, .title, .singer]
        cortinaItemOrder = try c.decodeIfPresent([DisplayTextItem].self, forKey: .cortinaItemOrder) ?? [.genre, .artist, .year, .singer]
    }

    public func singerValue(from track: Track) -> String? {
        guard showSinger else { return nil }
        switch singerSource {
        case .comments:    return track.comment
        case .albumArtist: return track.albumArtist
        }
    }

    public static let builtIns: [AppearanceProfile] = [.classic, .modern, .highContrast]

    public static let classic = AppearanceProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Classic", isBuiltIn: true,
        backgroundColor: "#1A1208",
        titleColor: "#F5E6C8", artistColor: "#F5E6C8", genreColor: "#C8A97A",
        trackCounterColor: "#C8A97A"
    )

    public static let modern = AppearanceProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Modern", isBuiltIn: true,
        backgroundColor: "#1C1C1E",
        titleColor: "#FFFFFF", artistColor: "#FFFFFF", genreColor: "#8E8E93",
        trackCounterColor: "#8E8E93"
    )

    public static let highContrast = AppearanceProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "High Contrast", isBuiltIn: true,
        backgroundColor: "#000000",
        titleColor: "#FFFF00", artistColor: "#FFFF00", genreColor: "#FFFFFF",
        trackCounterColor: "#B3B3B3",
        transitionStyle: .cut, transitionDuration: 0.0
    )
}

public enum DisplayTextItem: String, Codable, CaseIterable {
    case genre, artist, year, title, singer

    public var displayName: String {
        switch self {
        case .genre:  "Genre"
        case .artist: "Artist"
        case .year:   "Year"
        case .title:  "Title"
        case .singer: "Singer"
        }
    }
}

public enum SingerSource: String, Codable, CaseIterable {
    case comments    = "comments"
    case albumArtist = "albumArtist"

    public var displayName: String {
        switch self {
        case .comments:    "Comments"
        case .albumArtist: "Album Artist"
        }
    }
}

public enum TransitionStyle: String, Codable, CaseIterable {
    case fade
    case cut
    case fadeToBlack

    public var displayName: String {
        switch self {
        case .fade: "Crossfade"
        case .cut: "Hard Cut"
        case .fadeToBlack: "Fade Through Black"
        }
    }
}
