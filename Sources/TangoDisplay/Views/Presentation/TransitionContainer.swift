import SwiftUI
import TangoDisplayCore

struct TransitionContainer<Content: View, Identity: Hashable>: View {
    let identity: Identity
    let style: TransitionStyle
    let duration: Double
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .id(identity)
            .transition(transition(for: style))
            .animation(.easeInOut(duration: duration), value: identity)
    }

    private func transition(for style: TransitionStyle) -> AnyTransition {
        switch style {
        case .fade:
            return .opacity
        case .cut:
            return .identity
        case .fadeToBlack:
            // Fade out to black, then fade in from black
            return .asymmetric(
                insertion: .opacity.animation(.easeIn(duration: duration / 2).delay(duration / 2)),
                removal:   .opacity.animation(.easeOut(duration: duration / 2))
            )
        case .push:
            return .push(from: .trailing)
        case .zoom:
            return .asymmetric(
                insertion: .scale(scale: 0.3).combined(with: .opacity).animation(.easeOut(duration: duration)),
                removal:   .scale(scale: 1.5).combined(with: .opacity).animation(.easeIn(duration: duration))
            )
        }
    }
}
