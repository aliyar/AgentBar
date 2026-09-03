import SwiftUI

/// The panel's own tooltip.
///
/// `help(_:)` hands the text to AppKit, which waits out the system's tooltip delay -
/// something over a second, not ours to set - and draws it in the system's own yellow.
/// Inside a panel that answers a glance, a second is the whole visit. This one appears in
/// a third of that, in the panel's materials, and follows the row it belongs to.
///
/// A tip is drawn once, by the panel, over everything: `tipLayer()` at the root, `tip(_:)`
/// on anything that has something to say. The row reports where it is, in the panel's own
/// coordinate space, and the layer places the card there - above the row when there is
/// room below and below it when there is not, always clear of the panel's edges.
struct Tip: Equatable {
    let text: String
    /// Where the thing that owns the tip sits, in the panel's coordinate space.
    let anchor: CGRect
}

enum TipSpace {
    static let name = "tip-space"
    /// Long enough that a cursor crossing the panel raises nothing, short enough that
    /// resting is answered before it feels like waiting.
    static let delay: Duration = .milliseconds(320)
}

private struct TipKey: PreferenceKey {
    static let defaultValue: Tip? = nil
    static func reduce(value: inout Tip?, nextValue: () -> Tip?) {
        value = nextValue() ?? value
    }
}

private struct TipModifier: ViewModifier {
    let text: String?
    @State private var showing = false
    @State private var waiting: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: TipKey.self,
                        value: showing && text?.isEmpty == false
                            ? Tip(text: text!, anchor: proxy.frame(in: .named(TipSpace.name)))
                            : nil)
                }
            }
            .onHover { inside in
                waiting?.cancel()
                guard inside, text?.isEmpty == false else { showing = false; return }
                waiting = Task {
                    try? await Task.sleep(for: TipSpace.delay)
                    guard !Task.isCancelled else { return }
                    showing = true
                }
            }
            .onDisappear { waiting?.cancel(); showing = false }
    }
}

extension View {
    /// Says something about this view when the pointer rests on it. Nil or empty says nothing.
    func tip(_ text: String?) -> some View {
        modifier(TipModifier(text: text))
    }

    /// The panel's tip layer: put it on the root, once, inside the panel's own frame.
    func tipLayer(style: TipStyle) -> some View {
        coordinateSpace(name: TipSpace.name)
            .overlayPreferenceValue(TipKey.self) { tip in
                GeometryReader { proxy in
                    if let tip {
                        TipCard(text: tip.text, style: style)
                            .modifier(TipPlacement(anchor: tip.anchor, panel: proxy.size))
                            .transition(.opacity.animation(.easeOut(duration: 0.12)))
                    }
                }
                .allowsHitTesting(false)
            }
    }
}

/// How the card is drawn: each panel style dresses it in its own materials.
enum TipStyle {
    case glass(Palette.Glass)
    case terminal(TerminalPalette)
}

private struct TipCard: View {
    let text: String
    let style: TipStyle

    /// Wide enough for a sentence, never wider than the panel it sits in.
    static let maxWidth: CGFloat = 232

    var body: some View {
        switch style {
        case .glass(let glass):
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(glass.body)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .frame(maxWidth: Self.maxWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(glass.hairline))
                .shadow(color: .black.opacity(0.22), radius: 8, y: 3)
        case .terminal(let palette):
            Text(text)
                .font(TerminalOverview.mono(10.5))
                .foregroundStyle(palette.value)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: Self.maxWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .background(palette.panel, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(palette.hairline))
                .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
        }
    }
}

/// Above the row, or below it when the row is near the top; always inside the panel.
private struct TipPlacement: ViewModifier {
    let anchor: CGRect
    let panel: CGSize
    private static let gap: CGFloat = 6
    private static let margin: CGFloat = 8

    func body(content: Content) -> some View {
        content.fixedSize().background {
            GeometryReader { card in
                Color.clear.preference(key: SizeKey.self, value: card.size)
            }
        }
        .modifier(Place(anchor: anchor, panel: panel))
    }

    private struct SizeKey: PreferenceKey {
        static let defaultValue = CGSize.zero
        static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
    }

    private struct Place: ViewModifier {
        let anchor: CGRect
        let panel: CGSize
        @State private var size = CGSize.zero

        func body(content: Content) -> some View {
            content
                .onPreferenceChange(SizeKey.self) { size = $0 }
                .offset(x: x, y: y)
        }

        /// Left-aligned with the row, pulled back from the right edge when it would spill.
        private var x: CGFloat {
            min(max(TipPlacement.margin, anchor.minX),
                max(TipPlacement.margin, panel.width - size.width - TipPlacement.margin))
        }

        /// Above by preference: the pointer is on the row, and a card under it would be
        /// the next thing the pointer touches.
        private var y: CGFloat {
            let above = anchor.minY - size.height - TipPlacement.gap
            if above >= TipPlacement.margin { return above }
            return min(anchor.maxY + TipPlacement.gap, panel.height - size.height - TipPlacement.margin)
        }
    }
}
