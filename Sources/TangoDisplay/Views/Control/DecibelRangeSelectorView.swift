import SwiftUI

/// A horizontal three-band coloured bar (blue | green | red) with two draggable
/// threshold handles. The bar spans the full 0–140 dB integer range.
/// low  = blue/green boundary (0–139)
/// high = green/red boundary  (1–140, always > low)
struct DecibelRangeSelectorView: View {
    @Binding var low: Int
    @Binding var high: Int

    @State private var dragLowStartValue: Int = 0
    @State private var dragHighStartValue: Int = 0
    @State private var isDraggingLow = false
    @State private var isDraggingHigh = false

    private let totalRange: CGFloat = 140
    private let barHeight: CGFloat = 28
    private let handleWidth: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let lowFrac  = CGFloat(low)  / totalRange
            let highFrac = CGFloat(high) / totalRange

            ZStack(alignment: .topLeading) {
                // Three coloured bands
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.blue.opacity(0.75))
                        .frame(width: w * lowFrac)
                    Rectangle()
                        .fill(Color.green.opacity(0.75))
                        .frame(width: w * (highFrac - lowFrac))
                    Rectangle()
                        .fill(Color.red.opacity(0.75))
                        .frame(maxWidth: .infinity)
                }
                .frame(height: barHeight)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Low threshold handle
                handleView(value: low)
                    .offset(x: w * lowFrac - handleWidth / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                if !isDraggingLow {
                                    isDraggingLow = true
                                    dragLowStartValue = low
                                }
                                let delta = Int((drag.translation.width / w * totalRange).rounded())
                                low = max(0, min(high - 1, dragLowStartValue + delta))
                            }
                            .onEnded { _ in isDraggingLow = false }
                    )

                // High threshold handle
                handleView(value: high)
                    .offset(x: w * highFrac - handleWidth / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                if !isDraggingHigh {
                                    isDraggingHigh = true
                                    dragHighStartValue = high
                                }
                                let delta = Int((drag.translation.width / w * totalRange).rounded())
                                high = max(low + 1, min(140, dragHighStartValue + delta))
                            }
                            .onEnded { _ in isDraggingHigh = false }
                    )
            }
        }
        .frame(height: barHeight + 20)
    }

    private func handleView(value: Int) -> some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white)
                .frame(width: handleWidth, height: barHeight)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            Text("\(value)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 28, alignment: .center)
                .offset(x: -(28 - handleWidth) / 2)
        }
    }
}
