import SwiftUI

/// Reports how big each block drew, so the editor can hit-test and snap against
/// sizes it never has to guess.
struct BlockSizeKey: PreferenceKey {
    static var defaultValue: [String: CGSize] = [:]
    static func reduce(value: inout [String: CGSize], nextValue: () -> [String: CGSize]) {
        value.merge(nextValue()) { $1 }
    }
}

/// The card itself. Always laid out on a fixed 1000 × 630 canvas so that the on-screen
/// preview and the exported PNG are the same drawing at different scales.
///
/// Every piece is placed from `layout` rather than flowed, so the editor can move any
/// of them without the rest shifting underneath.
@MainActor
struct GiftCardView: View {

    static let canvas = CardLayout.canvas

    /// One knob for every piece of text on the card. The sizes this started from were
    /// tuned for a big preview; at the size the card is actually read they were small.
    /// The default placements are budgeted around whatever value sits here — change it
    /// and `CardLayout.standard` has to be re-checked for collisions.
    static let typeScale: CGFloat = 1.18

    let draft: GiftDraft
    let artwork: NSImage?
    var layout: CardLayout = .standard

    private var theme: GiftTheme { draft.theme }

    /// A measurement at the card's type scale, times whatever size the block itself
    /// has been given. Used for fonts and for the spacing that hangs off them, so a
    /// resized text block grows as a piece rather than just changing font size.
    private func t(_ size: CGFloat, _ block: CardBlock) -> CGFloat {
        (size * Self.typeScale * layout.scale(block)).rounded()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            background

            ForEach(CardBlock.allCases) { block in
                placed(block)
            }
        }
        .frame(width: Self.canvas.width, height: Self.canvas.height)
        .clipShape(RoundedRectangle(cornerRadius: 56, style: .continuous))
    }

    // MARK: - Placement

    @ViewBuilder
    private func placed(_ block: CardBlock) -> some View {
        let origin = layout.origin(block)
        content(for: block)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: BlockSizeKey.self,
                        value: [block.rawValue: proxy.size]
                    )
                }
            )
            .offset(x: origin.x, y: origin.y)
    }

    @ViewBuilder
    private func content(for block: CardBlock) -> some View {
        switch block {
        case .occasion: occasionView
        case .badge:    badgeView
        case .logo:     logoView
        case .title:    titleView
        case .message:  messageView
        case .people:   peopleView
        case .code:     codeView
        case .qr:       qrView
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            theme.gradient

            Circle()
                .fill(theme.blooms[0].opacity(0.55))
                .frame(width: 620, height: 620)
                .blur(radius: 140)
                .offset(x: -300, y: -230)

            Circle()
                .fill(theme.blooms[1].opacity(0.5))
                .frame(width: 700, height: 700)
                .blur(radius: 160)
                .offset(x: 330, y: 250)

            // Single diagonal sheen — the one flourish; everything else stays flat.
            LinearGradient(
                colors: [.white.opacity(0.26), .white.opacity(0.0)],
                startPoint: .topLeading,
                endPoint: .init(x: 0.62, y: 0.55)
            )
        }
        .frame(width: Self.canvas.width, height: Self.canvas.height)
    }

    // MARK: - Blocks

    private var occasionView: some View {
        Text(draft.occasion.isEmpty ? "선물" : draft.occasion)
            .font(.system(size: t(15, .occasion), weight: .bold, design: .rounded))
            .tracking(4.5 * layout.scale(.occasion))
            .textCase(.uppercase)
            .foregroundStyle(theme.ink.opacity(0.85))
    }

    private var badgeView: some View {
        Text("App Store에서 받기")
            .font(.system(size: t(14, .badge), weight: .semibold, design: .rounded))
            .foregroundStyle(theme.ink.opacity(0.75))
            .padding(.horizontal, 16 * layout.scale(.badge))
            .padding(.vertical, 8 * layout.scale(.badge))
            .background(
                Capsule().stroke(theme.ink.opacity(0.45), lineWidth: 1.2)
            )
    }

    private var logoView: some View {
        let side = 152 * layout.scale(.logo)
        let radius = 34 * layout.scale(.logo)
        return Group {
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.22)
                    Text(String(draft.app?.name.prefix(1) ?? "?"))
                        .font(.system(size: t(64, .logo), weight: .bold, design: .rounded))
                        .foregroundStyle(theme.ink.opacity(0.7))
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 26, x: 0, y: 14)
    }

    private var titleView: some View {
        VStack(alignment: .leading, spacing: 8 * layout.scale(.title)) {
            Text(draft.app?.name ?? "앱을 불러오세요")
                .font(.system(size: t(44, .title), weight: .bold, design: .rounded))
                .foregroundStyle(theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.6)

            Text(draft.app?.developer ?? "개발자")
                .font(.system(size: t(20, .title), weight: .medium, design: .rounded))
                .foregroundStyle(theme.inkSecondary)
                .lineLimit(1)
        }
        // The wrap width grows with the type, so the line breaks stay where they were
        // and the block's box tracks the grip being dragged.
        .frame(maxWidth: 640 * layout.scale(.title), alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var messageView: some View {
        if !draft.message.isEmpty {
            Text(draft.message)
                .font(.system(size: t(25, .message), weight: .regular, design: .rounded))
                .foregroundStyle(theme.ink.opacity(0.95))
                .lineSpacing(7 * layout.scale(.message))
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: 700 * layout.scale(.message), alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var peopleView: some View {
        if !draft.recipient.isEmpty || !draft.sender.isEmpty || draft.expiry != nil {
            VStack(alignment: .leading, spacing: 6 * layout.scale(.people)) {
                if !draft.recipient.isEmpty {
                    Text("To. \(draft.recipient)")
                        .font(.system(size: t(19, .people), weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.ink.opacity(0.9))
                }
                if !draft.sender.isEmpty {
                    Text("From. \(draft.sender)")
                        .font(.system(size: t(17, .people), weight: .medium, design: .rounded))
                        .foregroundStyle(theme.inkSecondary)
                }
                if let expiry = draft.expiry, draft.kind.hasExpiry {
                    Text("\(expiry, format: .dateTime.year().month().day())까지")
                        .font(.system(size: t(14, .people), weight: .medium, design: .rounded))
                        .foregroundStyle(theme.ink.opacity(0.65))
                        .padding(.top, 4 * layout.scale(.people))
                }
            }
            .fixedSize()
        }
    }

    @ViewBuilder
    private var codeView: some View {
        if draft.showCodeOnCard, draft.kind.requiresCode, !draft.trimmedCode.isEmpty {
            Text(draft.trimmedCode)
                .font(.system(size: t(18, .code), weight: .medium, design: .monospaced))
                .tracking(2 * layout.scale(.code))
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 20 * layout.scale(.code))
                .padding(.vertical, 13 * layout.scale(.code))
                .background(
                    RoundedRectangle(cornerRadius: 16 * layout.scale(.code), style: .continuous)
                        .stroke(style: StrokeStyle(lineWidth: 1.4, dash: [6, 5]))
                        .foregroundStyle(theme.ink.opacity(0.6))
                )
                .fixedSize()
        }
    }

    @ViewBuilder
    private var qrView: some View {
        if draft.showQRCode,
           let link = draft.redeemURL?.absoluteString,
           let qr = QRCodeRenderer.image(from: link, size: 256) {
            let side = 104 * layout.scale(.qr)
            Image(nsImage: qr)
                .resizable()
                .interpolation(.none)
                .frame(width: side, height: side)
                .padding(9 * layout.scale(.qr))
                .background(
                    RoundedRectangle(cornerRadius: 16 * layout.scale(.qr), style: .continuous)
                        .fill(.white)
                )
        }
    }
}

// MARK: - Drag-to-place editor

/// The preview with the card's pieces draggable.
///
/// The card is drawn scaled to fit, but the selection chrome is drawn in view
/// coordinates so the outline and the resize grip stay the same size on screen no
/// matter how far the canvas has been shrunk.
@MainActor
struct EditableCardPreview: View {

    let draft: GiftDraft
    let artwork: NSImage?
    @Binding var layout: CardLayout
    @Binding var selection: CardBlock?

    /// What each block measured, for hit-testing and snapping. It stays inside the
    /// editor now — the gift link no longer carries block footprints.
    @State private var sizes: [String: CGSize] = [:]
    @State private var hover: CardBlock?
    @State private var drag: DragState?
    @State private var guides: [SnapGuide] = []
    @FocusState private var focused: Bool

    /// Snap threshold and grip size, in canvas points and view points respectively.
    private let snapThreshold: CGFloat = 7
    private let chromeInset: CGFloat = 6
    private let gripSide: CGFloat = 12

    private enum Mode {
        case move(grab: CGSize)      // pointer offset inside the block when grabbed
        case resize(baseSide: CGFloat)
    }

    private struct DragState {
        var block: CardBlock
        var mode: Mode
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / GiftCardView.canvas.width,
                proxy.size.height / GiftCardView.canvas.height
            )
            let size = CGSize(
                width: GiftCardView.canvas.width * scale,
                height: GiftCardView.canvas.height * scale
            )

            ZStack(alignment: .topLeading) {
                // Scaling about the top-left only lands on the frame if the card's
                // layout box is pinned there too — left centred, it shrinks away from
                // the corner and half the card falls outside.
                GiftCardView(draft: draft, artwork: artwork, layout: layout)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                    .shadow(color: .black.opacity(0.28), radius: 30, x: 0, y: 18)

                chrome(scale: scale)
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(dragGesture(scale: scale))
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    guard drag == nil else { return }
                    hover = block(at: CGPoint(x: point.x / scale, y: point.y / scale))
                case .ended:
                    hover = nil
                }
            }
            .focusable()
            .focusEffectDisabled()
            .focused($focused)
            .onKeyPress { press in handle(press) }
            .onPreferenceChange(BlockSizeKey.self) { measured in
                sizes = measured
            }
            .overlay(alignment: .bottom) { collisionBanner }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Chrome

    @ViewBuilder
    private func chrome(scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(guides.enumerated()), id: \.offset) { _, guide in
                Path { path in
                    if guide.vertical {
                        path.move(to: CGPoint(x: guide.at * scale, y: 0))
                        path.addLine(to: CGPoint(x: guide.at * scale, y: GiftCardView.canvas.height * scale))
                    } else {
                        path.move(to: CGPoint(x: 0, y: guide.at * scale))
                        path.addLine(to: CGPoint(x: GiftCardView.canvas.width * scale, y: guide.at * scale))
                    }
                }
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }

            // Overlap first, so a selected block still gets the accent outline on top.
            ForEach(collidingBlocks, id: \.self) { block in
                if let box = viewRect(block, scale: scale) {
                    warningOutline(box)
                }
            }

            if let hover, hover != selection, let box = viewRect(hover, scale: scale) {
                outline(box, strong: false)
            }
            if let selection, let box = viewRect(selection, scale: scale) {
                outline(box, strong: true)
                label(for: selection, box: box)
                grip(box: box)
            }
        }
        .allowsHitTesting(false)
    }

    /// Says which two blocks are on top of each other, and offers the one move that
    /// undoes it. It sits on the card rather than in the toolbar because that's where
    /// the orange boxes are.
    @ViewBuilder
    private var collisionBanner: some View {
        let pairs = layout.collisions(sizes: sizes)
        if let (a, b) = pairs.first {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                Text(
                    pairs.count > 1
                        ? "\(a.label)과 \(b.label)를 비롯해 \(pairs.count)곳이 겹칩니다"
                        : "\(a.label)과 \(b.label)가 겹칩니다"
                )
                .font(.system(size: 12, weight: .medium))

                Text("내보내는 이미지에도 그대로 나갑니다")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Button("겹친 것만 되돌리기") { resetColliding() }
                    .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.orange.opacity(0.5), lineWidth: 1))
            .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
            .padding(.bottom, 10)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// Puts just the offending blocks back where they started, leaving the rest of the
    /// arrangement alone — "배치 초기화" throws away everything, which is too much when
    /// one enlarged icon is the problem.
    private func resetColliding() {
        for block in collidingBlocks {
            layout[block] = CardLayout.standard[block]
        }
        layout.save()
    }

    /// Blocks currently running into another one, in card order.
    private var collidingBlocks: [CardBlock] {
        var hit: Set<CardBlock> = []
        for (a, b) in layout.collisions(sizes: sizes) { hit.insert(a); hit.insert(b) }
        return CardBlock.allCases.filter(hit.contains)
    }

    /// What the message-over-the-icon case looks like before you export it.
    private func warningOutline(_ box: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.orange.opacity(0.14))
            )
            .frame(width: box.width, height: box.height)
            .offset(x: box.minX, y: box.minY)
    }

    private func outline(_ box: CGRect, strong: Bool) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .stroke(
                Color.accentColor.opacity(strong ? 1 : 0.5),
                style: StrokeStyle(lineWidth: strong ? 2 : 1.5, dash: strong ? [] : [5, 4])
            )
            .frame(width: box.width, height: box.height)
            .offset(x: box.minX, y: box.minY)
    }

    private func label(for block: CardBlock, box: CGRect) -> some View {
        let text = "\(block.label)  \(Int((layout.scale(block) * 100).rounded()))%"
        // Flip below the block when there's no room above.
        let above = box.minY - 22
        return Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.accentColor))
            .offset(x: box.minX, y: above < 0 ? box.maxY + 4 : above)
    }

    private func grip(box: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(.white)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.accentColor, lineWidth: 2))
            .frame(width: gripSide, height: gripSide)
            .offset(x: box.maxX - gripSide / 2, y: box.maxY - gripSide / 2)
    }

    // MARK: Geometry

    private func canvasSize(_ block: CardBlock) -> CGSize? {
        guard let size = sizes[block.rawValue], size.width > 0, size.height > 0 else { return nil }
        return size
    }

    private func canvasRect(_ block: CardBlock) -> CGRect? {
        layout.rect(block, sizes: sizes)
    }

    /// The block's box in view points, padded out to the selection outline.
    private func viewRect(_ block: CardBlock, scale: CGFloat) -> CGRect? {
        guard let rect = canvasRect(block) else { return nil }
        return CGRect(
            x: rect.minX * scale - chromeInset,
            y: rect.minY * scale - chromeInset,
            width: rect.width * scale + chromeInset * 2,
            height: rect.height * scale + chromeInset * 2
        )
    }

    private func block(at point: CGPoint) -> CardBlock? {
        layout.block(at: point, sizes: sizes)
    }

    private func hitsGrip(_ point: CGPoint, block: CardBlock, scale: CGFloat) -> Bool {
        guard let box = viewRect(block, scale: scale) else { return false }
        let grip = CGRect(
            x: box.maxX - gripSide / 2, y: box.maxY - gripSide / 2,
            width: gripSide, height: gripSide
        ).insetBy(dx: -5, dy: -5)
        return grip.contains(CGPoint(x: point.x * scale, y: point.y * scale))
    }

    // MARK: Moving

    private func move(_ block: CardBlock, to origin: CGPoint, snapping: Bool) {
        guard let size = canvasSize(block) else { return }
        var point = origin
        if snapping {
            let result = layout.snapping(
                point, block: block, size: size, sizes: sizes, threshold: snapThreshold
            )
            point = result.origin
            guides = result.guides
        } else {
            guides = []
        }
        layout.setOrigin(CardLayout.clamped(point, size: size), for: block)
    }

    private func keepInside(_ block: CardBlock) {
        guard let size = canvasSize(block) else { return }
        layout.setOrigin(CardLayout.clamped(layout.origin(block), size: size), for: block)
    }

    // MARK: Gestures

    private func dragGesture(scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let point = CGPoint(x: value.location.x / scale, y: value.location.y / scale)
                focused = true

                if let state = drag {
                    apply(state, at: point, modifiers: NSEvent.modifierFlags)
                    return
                }

                // The grip sits outside the block's own box, so it's tested first.
                if let selection, hitsGrip(point, block: selection, scale: scale),
                   let size = canvasSize(selection) {
                    drag = DragState(
                        block: selection,
                        mode: .resize(baseSide: size.width / layout.scale(selection))
                    )
                    return
                }

                guard let hit = block(at: point), let rect = canvasRect(hit) else {
                    selection = nil
                    return
                }
                selection = hit
                drag = DragState(
                    block: hit,
                    mode: .move(grab: CGSize(width: point.x - rect.minX, height: point.y - rect.minY))
                )
            }
            .onEnded { _ in
                guard drag != nil else { return }
                drag = nil
                guides = []
                layout.save()
            }
    }

    private func apply(_ state: DragState, at point: CGPoint, modifiers: NSEvent.ModifierFlags) {
        switch state.mode {
        case .move(let grab):
            move(
                state.block,
                to: CGPoint(x: point.x - grab.width, y: point.y - grab.height),
                snapping: !modifiers.contains(.option)
            )
        case .resize(let baseSide):
            guard baseSide > 0, let rect = canvasRect(state.block) else { return }
            var wanted = Double((point.x - rect.minX) / baseSide)
            if !modifiers.contains(.option) {
                wanted = (wanted * 20).rounded() / 20      // 5% steps, Option to go free
            }
            layout.setScale(wanted, for: state.block)
            keepInside(state.block)
        }
    }

    // MARK: Keyboard

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        if press.key == .escape {
            selection = nil
            return .handled
        }
        guard let block = selection else { return .ignored }

        if press.characters == "+" || press.characters == "=" ||
            press.characters == "-" || press.characters == "_" {
            let up = press.characters == "+" || press.characters == "="
            let step = press.modifiers.contains(.shift) ? 0.2 : 0.05
            layout.setScale(layout.scale(block) + (up ? step : -step), for: block)
            keepInside(block)
            layout.save()
            return .handled
        }

        let steps: [KeyEquivalent: CGPoint] = [
            .leftArrow:  CGPoint(x: -1, y: 0),
            .rightArrow: CGPoint(x: 1, y: 0),
            .upArrow:    CGPoint(x: 0, y: -1),
            .downArrow:  CGPoint(x: 0, y: 1)
        ]
        guard let step = steps[press.key] else { return .ignored }

        let amount: CGFloat = press.modifiers.contains(.shift) ? 10 : 1
        let origin = layout.origin(block)
        move(
            block,
            to: CGPoint(x: origin.x + step.x * amount, y: origin.y + step.y * amount),
            snapping: false
        )
        layout.save()
        return .handled
    }
}

/// Scales the fixed canvas down to fit whatever space the window gives it.
@MainActor
struct GiftCardPreview: View {
    let draft: GiftDraft
    let artwork: NSImage?
    var layout: CardLayout = .standard

    var body: some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / GiftCardView.canvas.width,
                proxy.size.height / GiftCardView.canvas.height
            )
            GiftCardView(draft: draft, artwork: artwork, layout: layout)
                .scaleEffect(scale)
                .frame(
                    width: GiftCardView.canvas.width * scale,
                    height: GiftCardView.canvas.height * scale
                )
                .shadow(color: .black.opacity(0.28), radius: 30, x: 0, y: 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
