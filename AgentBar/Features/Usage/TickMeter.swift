import SwiftUI

/// A row of ticks, the lit ones showing how much is spent. Ticks keep their edges at any
/// size and in either theme, where a 3 %-filled hairline simply disappears; a single lit
/// tick is still a tick.
struct TickMeter: View {
    let fraction: Double
    let tint: Color
    var ticks: Int = 44
    var height: CGFloat = 8
    var gap: CGFloat = 1
    /// A window that has already rolled over: the track alone, nothing lit.
    var dimmed = false

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let clamped = min(1, max(0, fraction))
        // Anything above nothing lights at least one tick: a value that rounds to zero
        // is still not the same as no usage at all.
        let lit = dimmed ? 0 : (clamped > 0 ? max(1, Int((Double(ticks) * clamped).rounded())) : 0)
        let track = Palette.glass(scheme).track
        HStack(spacing: gap) {
            ForEach(0..<ticks, id: \.self) { index in
                RoundedRectangle(cornerRadius: 0.5, style: .continuous)
                    .fill(index < lit ? tint : track.opacity(dimmed ? 0.55 : 1))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height)
    }
}
