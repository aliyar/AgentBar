import SwiftUI

/// The panel's own tooltip.
///
/// `help(_:)` hands the text to AppKit, which waits out the system's tooltip delay -
/// something over a second, not ours to set - and draws it in the system's own yellow.
/// This one is the panel's: it appears sooner, in one dark card whatever the appearance,
/// and it is placed against the row it belongs to.
///
/// A tip is drawn once, by the panel: `tipLayer()` at the root, `tip(_:_:)` on anything
/// that has something to say. The row reports where it is, in the panel's coordinate
/// space, and the layer places the card above it - or below, when there is no room -
/// always clear of the panel's edges.
///
/// A tip is a **heading and a line about it**, not a sentence: the heading names what is
/// under the pointer and the line says the thing worth reading. A paragraph in a card the
/// size of a row is read by nobody.
struct Tip: Equatable {
    /// What the pointer is on: a window's name, a person's name.
    let title: String?
    /// The one line worth reading about it.
    let detail: String?
    /// Where the thing that owns the tip sits, in the panel's coordinate space.
    let anchor: CGRect

    var isEmpty: Bool { (title ?? "").isEmpty && (detail ?? "").isEmpty }
}

enum TipSpace {
    static let name = "tip-space"
    /// Long enough that a pointer crossing the panel raises nothing and a rest is
    /// deliberate; short enough that the answer still feels like part of the glance.
    static let delay: Duration = .milliseconds(620)
}

private struct TipKey: PreferenceKey {
    static let defaultValue: Tip? = nil
    static func reduce(value: inout Tip?, nextValue: () -> Tip?) {
        value = nextValue() ?? value
    }
}

private struct TipModifier: ViewModifier {
    let title: String?
    let detail: String?
    @State private var showing = false
    @State private var waiting: Task<Void, Never>?

    private var hasSomethingToSay: Bool { !(title ?? "").isEmpty || !(detail ?? "").isEmpty }

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: TipKey.self,
                        value: showing && hasSomethingToSay
                            ? Tip(title: title, detail: detail, anchor: proxy.frame(in: .named(TipSpace.name)))
                            : nil)
                }
            }
            .onHover { inside in
                waiting?.cancel()
                guard inside, hasSomethingToSay else { showing = false; return }
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
    /// Says one line about this view when the pointer rests on it.
    func tip(_ detail: String?) -> some View {
        modifier(TipModifier(title: nil, detail: detail))
    }

    /// Names what the pointer is on, then says the line worth reading about it.
    func tip(_ title: String?, _ detail: String?) -> some View {
        modifier(TipModifier(title: title, detail: detail))
    }

    /// The panel's tip layer: put it on the root, once, inside the panel's own frame.
    func tipLayer(mono: Bool) -> some View {
        coordinateSpace(name: TipSpace.name)
            .overlayPreferenceValue(TipKey.self) { tip in
                GeometryReader { proxy in
                    if let tip, !tip.isEmpty {
                        TipCard(tip: tip, mono: mono)
                            .modifier(TipPlacement(anchor: tip.anchor, panel: proxy.size))
                            .transition(.opacity.animation(.easeOut(duration: 0.11)))
                    }
                }
                .allowsHitTesting(false)
            }
    }
}

/// One card, dark in both appearances.
///
/// A tip sits over the panel's own materials, and a translucent card over a translucent
/// panel is two half-legible layers. This one is solid, and dark whichever way the panel
/// is: an interface's tooltip is a note held over the page, not part of it - the Mac's own
/// have always been their own colour rather than the window's.
private struct TipCard: View {
    let tip: Tip
    let mono: Bool

    /// Wide enough for a name and its address on one line, and to keep a sentence to two.
    static let maxWidth: CGFloat = 254
    static let fill = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let heading = Color.white.opacity(0.95)
    static let body = Color.white.opacity(0.66)
    static let edge = Color.white.opacity(0.11)

    /// What the words want if nothing wraps them. `frame(maxWidth:)` takes every point it
    /// is offered, so a card holding "Settings…" would be as wide as one holding a
    /// sentence; the card is given the smaller of this and the maximum instead.
    @State private var natural: CGFloat = 0

    private func font(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        mono ? .system(size: size, weight: weight, design: .monospaced) : .system(size: size, weight: weight)
    }

    @ViewBuilder private var words: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let title = tip.title, !title.isEmpty {
                Text(title)
                    .font(font(11.5, .semibold))
                    .foregroundStyle(Self.heading)
            }
            if let detail = tip.detail, !detail.isEmpty {
                Text(detail)
                    .font(font(11, .regular))
                    .foregroundStyle(tip.title == nil ? Self.heading : Self.body)
            }
        }
        .lineSpacing(1.5)
        .multilineTextAlignment(.leading)
    }

    var body: some View {
        words
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: natural > 0 ? min(natural, Self.maxWidth) : nil, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Self.fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Self.edge))
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            // The same words laid out with nothing to wrap them, measured and thrown away.
            .background {
                words
                    .fixedSize()
                    .background {
                        GeometryReader { proxy in
                            Color.clear
                                .onAppear { natural = proxy.size.width }
                                .onChange(of: proxy.size.width) { _, new in natural = new }
                        }
                    }
                    .hidden()
            }
    }
}

/// Above the row, or below it when the row is near the top; always inside the panel.
private struct TipPlacement: ViewModifier {
    let anchor: CGRect
    let panel: CGSize
    private static let gap: CGFloat = 6
    private static let margin: CGFloat = 8

    @State private var size = CGSize.zero

    func body(content: Content) -> some View {
        // The card sizes itself: `frame(maxWidth:)` inside it wraps the text, and a
        // `fixedSize()` here would override that and let a long line run past the edge.
        content
            .background {
                GeometryReader { card in
                    Color.clear
                        .onAppear { size = card.size }
                        .onChange(of: card.size) { _, new in size = new }
                }
            }
            .offset(x: x, y: y)
            .opacity(size == .zero ? 0 : 1)
    }

    /// Left-aligned with the row, pulled back from the right edge when it would spill.
    private var x: CGFloat {
        min(max(Self.margin, anchor.minX),
            max(Self.margin, panel.width - size.width - Self.margin))
    }

    /// Above by preference: the pointer is on the row, and a card under it would be the
    /// next thing the pointer touches.
    private var y: CGFloat {
        let above = anchor.minY - size.height - Self.gap
        if above >= Self.margin { return above }
        return min(anchor.maxY + Self.gap, panel.height - size.height - Self.margin)
    }
}
