import SwiftUI

/// The app's mark as the panel header shows it: the outline, arrow and prompt in the text
/// colour, the block cursor in the brand green - `Design/Icon/mark-mono.svg`, whose
/// `currentColor` strokes come from the template image and whose cursor is drawn here on
/// top, since a template image tints every part alike.
struct MarkView: View {
    var size: CGFloat = 16
    var tint: Color = .primary
    /// The cursor's green: calm-dark on dark panels, calm-light on light ones.
    var cursor: Color

    var body: some View {
        Image("MarkMono")
            .resizable()
            .foregroundStyle(tint)
            .overlay(alignment: .topLeading) {
                // The cursor's place on the 18-point grid: 3.2 wide at (9.4, 9), radius 0.7.
                RoundedRectangle(cornerRadius: size * 0.7 / 18, style: .continuous)
                    .fill(cursor)
                    .frame(width: size * 3.2 / 18, height: size * 3.2 / 18)
                    .offset(x: size * 9.4 / 18, y: size * 9 / 18)
            }
            .frame(width: size, height: size)
    }
}
