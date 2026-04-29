import SwiftUI
import TangoDisplayCore

struct CortinaView: View {
    let state: DisplayState
    let profile: AppearanceProfile
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Cortina label
            Text(settings.cortinaLabel)
                .font(profile.titleFont)
                .tracking(12)
                .foregroundColor(profile.artistSwiftUIColor)
                .multilineTextAlignment(.center)

            if let next = state.nextTrack {
                // Divider
                Rectangle()
                    .fill(profile.genreSwiftUIColor.opacity(0.3))
                    .frame(width: 120, height: 1)
                    .padding(.vertical, 8)

                // Coming up section
                VStack(spacing: 12) {
                    Text(settings.nextUpLabel)
                        .font(profile.genreFont)
                        .tracking(4)
                        .foregroundColor(profile.genreSwiftUIColor)

                    ForEach(profile.cortinaItemOrder, id: \.self) { item in
                        switch item {
                        case .genre:
                            if !next.genre.isEmpty {
                                Text(next.genre)
                                    .font(profile.genreFont)
                                    .foregroundColor(profile.genreSwiftUIColor)
                            }
                        case .artist:
                            Text(next.artist)
                                .font(profile.artistFont)
                                .foregroundColor(profile.artistSwiftUIColor)
                                .lineLimit(2)
                                .minimumScaleFactor(0.5)
                                .multilineTextAlignment(.center)
                        case .year:
                            if profile.showYear, let year = next.year {
                                Text(String(year))
                                    .font(profile.yearFont)
                                    .foregroundColor(profile.yearSwiftUIColor)
                                    .multilineTextAlignment(.center)
                            }
                        case .title:
                            if !next.title.isEmpty {
                                Text(next.title)
                                    .font(profile.titleFont)
                                    .foregroundColor(profile.titleSwiftUIColor)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.5)
                            }
                        case .singer:
                            if profile.showSingerDuringCortina,
                               let singer = profile.singerValue(from: next), !singer.isEmpty {
                                Text(singer)
                                    .font(profile.singerFont)
                                    .foregroundColor(profile.singerSwiftUIColor)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.5)
                            }
                        }
                    }
                }
                .padding(.horizontal, 60)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
