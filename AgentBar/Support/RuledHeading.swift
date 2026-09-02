import SwiftUI

/// A small label with a rule running out to the edge - enough structure to group by,
/// without a heavy header on every block.
struct RuledHeading: View {
    let text: String
    var symbol: String?
    var tint: Color?
    var trailing: String?

    var body: some View {
        HStack(spacing: 6) {
            if let symbol, let tint {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(tint)
            }
            Text(text.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(height: 1)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
