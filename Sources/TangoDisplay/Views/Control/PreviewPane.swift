import SwiftUI
import TangoDisplayCore

/// Scaled-down mirror of the PresentationView.
/// Uses scaleEffect on a fixed-size container so the presentation layout is
/// identical to the real thing, just smaller.
struct PreviewPane: View {
    @EnvironmentObject var appState: AppState

    private let targetWidth:  CGFloat = 1920
    private let targetHeight: CGFloat = 1080

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / targetWidth
            let pw    = geo.size.width
            let ph    = targetHeight * scale

            ZStack(alignment: .topLeading) {
                // Mirror the PresentationView at scale
                PresentationView(isPreview: true)
                    .environmentObject(appState)
                    .environmentObject(appState.settings)
                    .frame(width: targetWidth, height: targetHeight)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: pw, height: ph, alignment: .topLeading)
                    .allowsHitTesting(false)
                    .clipped()

                // Border
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1)
                    .frame(width: pw, height: ph)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
