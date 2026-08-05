import Foundation
import CoreGraphics

// MARK: - Card layout

/// A piece of the card that can be placed on its own.
enum CardBlock: String, CaseIterable, Codable, Identifiable {
    case occasion, badge, logo, title, message, people, code, qr

    var id: String { rawValue }

    /// The name the editor calls this block, in the interface's language — the operator
    /// reads it, not the recipient.
    var label: String {
        let loc: Loc
        switch self {
        case .occasion: loc = T.blockOccasion
        case .badge:    loc = T.blockBadge
        case .logo:     loc = T.blockLogo
        case .title:    loc = T.blockTitle
        case .message:  loc = T.blockMessage
        case .people:   loc = T.blockPeople
        case .code:     loc = T.blockCode
        case .qr:       loc = T.blockQR
        }
        return loc.text
    }

    /// Artwork scales its frame; text scales its font. Either way the block carries
    /// its own size alongside its position, so every one of them can be resized.
    var scalesArtwork: Bool { self == .logo || self == .qr }
}

/// Where one block sits, as a fraction of the canvas so the same numbers place it
/// in the on-screen preview and in the 3000pt export.
struct BlockPlacement: Codable, Hashable {
    var x: Double
    var y: Double
    var scale: Double = 1
}

/// The placement of every block on the card.
///
/// Stored as fractions of `GiftCardView.canvas`. The defaults reproduce the chosen
/// style's composition — nothing moves until the user drags something.
struct CardLayout: Codable, Hashable {

    static let canvas = CGSize(width: 1000, height: 630)
    static let padding: CGFloat = 56
    static let scaleRange: ClosedRange<Double> = 0.4...2.5

    /// Which design these placements belong to. Carried on the layout itself so that
    /// "what is the default here?" and "where do I save this?" never need the caller to
    /// remember — the two questions that would otherwise let one style's arrangement
    /// leak into another's.
    var style: CardStyle = .classic

    /// Keyed by `CardBlock.rawValue` — a plain string dictionary so the JSON stays
    /// readable and survives a block being added or renamed.
    private var placements: [String: BlockPlacement]

    init(style: CardStyle = .classic, placements: [String: BlockPlacement] = [:]) {
        self.style = style
        self.placements = placements
    }

    /// The arrangement a style opens with.
    static func defaults(for style: CardStyle) -> CardLayout {
        CardLayout(style: style, placements: style.defaultPlacements)
    }

    subscript(block: CardBlock) -> BlockPlacement {
        get {
            placements[block.rawValue]
                ?? style.defaultPlacements[block.rawValue]
                ?? BlockPlacement(x: 0, y: 0)
        }
        set { placements[block.rawValue] = newValue }
    }

    /// The block's own size multiplier — a frame multiplier for artwork, a font
    /// multiplier for text.
    func scale(_ block: CardBlock) -> CGFloat {
        CGFloat(self[block].scale)
    }

    /// Top-left corner of the block in canvas points.
    func origin(_ block: CardBlock) -> CGPoint {
        let p = self[block]
        return CGPoint(x: p.x * CardLayout.canvas.width, y: p.y * CardLayout.canvas.height)
    }

    mutating func setOrigin(_ point: CGPoint, for block: CardBlock) {
        var p = self[block]
        p.x = Double(point.x / CardLayout.canvas.width)
        p.y = Double(point.y / CardLayout.canvas.height)
        self[block] = p          // writes the fields, keeping the scale
    }

    mutating func setScale(_ value: Double, for block: CardBlock) {
        var p = self[block]
        p.scale = min(max(value, CardLayout.scaleRange.lowerBound), CardLayout.scaleRange.upperBound)
        self[block] = p
    }

    /// Whether nothing has been moved from where this style put it.
    var isDefault: Bool {
        let defaults = CardLayout.defaults(for: style)
        return CardBlock.allCases.allSatisfy { block in
            let a = self[block], b = defaults[block]
            return abs(a.x - b.x) < 1e-6 && abs(a.y - b.y) < 1e-6 && abs(a.scale - b.scale) < 1e-6
        }
    }
}

// MARK: - Card layout geometry

/// A snap line the editor draws while a block is being dragged.
struct SnapGuide: Hashable {
    var vertical: Bool
    var at: CGFloat        // canvas coordinate
}

/// The arithmetic behind dragging, kept out of the view so it can be reasoned about
/// on its own. `sizes` is how big each block measured, keyed by `CardBlock.rawValue`.
extension CardLayout {

    func rect(_ block: CardBlock, sizes: [String: CGSize]) -> CGRect? {
        guard let size = sizes[block.rawValue], size.width > 0, size.height > 0 else { return nil }
        return CGRect(origin: origin(block), size: size)
    }

    /// The block under a point, or nil. Later blocks win an overlap, matching what
    /// the eye sees, since they're drawn on top.
    func block(at point: CGPoint, sizes: [String: CGSize], slack: CGFloat = 6) -> CardBlock? {
        for block in CardBlock.allCases.reversed() {
            guard let rect = rect(block, sizes: sizes) else { continue }
            if rect.insetBy(dx: -slack, dy: -slack).contains(point) { return block }
        }
        return nil
    }

    /// Pairs of blocks whose boxes run into each other.
    ///
    /// Growing a block is the easy way into this: the app icon at 145% reaches 220pt
    /// down from its corner and lands on the message, which draws later and so covers
    /// it. Nothing in the card itself objects, and the PNG bakes it in — so the editor
    /// asks here and says something.
    ///
    /// `slack` forgives blocks that merely touch: text boxes carry a little leading
    /// past their glyphs, and a 2pt kiss isn't what anyone means by overlapping.
    func collisions(sizes: [String: CGSize], slack: CGFloat = 3) -> [(CardBlock, CardBlock)] {
        var found: [(CardBlock, CardBlock)] = []
        let blocks = CardBlock.allCases
        for (index, a) in blocks.enumerated() {
            guard let ra = rect(a, sizes: sizes) else { continue }
            for b in blocks.dropFirst(index + 1) {
                guard let rb = rect(b, sizes: sizes) else { continue }
                let hit = ra.insetBy(dx: slack, dy: slack).intersection(rb.insetBy(dx: slack, dy: slack))
                if !hit.isNull, hit.width > 0, hit.height > 0 { found.append((a, b)) }
            }
        }
        return found
    }

    /// Keeps a block on the card — one dragged or grown past an edge would be
    /// unreachable.
    static func clamped(_ origin: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(origin.x, 0), max(0, canvas.width - size.width)),
            y: min(max(origin.y, 0), max(0, canvas.height - size.height))
        )
    }

    /// Pulls an origin onto the padding lines, the card centre, or the edges of the
    /// other blocks, and reports the lines it landed on.
    func snapping(
        _ origin: CGPoint,
        block: CardBlock,
        size: CGSize,
        sizes: [String: CGSize],
        threshold: CGFloat = 7
    ) -> (origin: CGPoint, guides: [SnapGuide]) {

        var xs: [CGFloat] = [
            CardLayout.padding,
            CardLayout.canvas.width - CardLayout.padding - size.width,
            (CardLayout.canvas.width - size.width) / 2
        ]
        var ys: [CGFloat] = [
            CardLayout.padding,
            CardLayout.canvas.height - CardLayout.padding - size.height,
            (CardLayout.canvas.height - size.height) / 2
        ]

        for other in CardBlock.allCases where other != block {
            guard let rect = rect(other, sizes: sizes) else { continue }
            xs.append(contentsOf: [rect.minX, rect.maxX - size.width])
            ys.append(contentsOf: [rect.minY, rect.maxY - size.height])
        }

        var result = origin
        var guides: [SnapGuide] = []
        if let hit = CardLayout.nearest(origin.x, xs, threshold) {
            result.x = hit
            guides.append(SnapGuide(vertical: true, at: hit))
        }
        if let hit = CardLayout.nearest(origin.y, ys, threshold) {
            result.y = hit
            guides.append(SnapGuide(vertical: false, at: hit))
        }
        return (result, guides)
    }

    private static func nearest(_ value: CGFloat, _ targets: [CGFloat], _ threshold: CGFloat) -> CGFloat? {
        var best: (distance: CGFloat, value: CGFloat)?
        for target in targets {
            let distance = abs(value - target)
            if distance < threshold, best == nil || distance < best!.distance {
                best = (distance, target)
            }
        }
        return best?.value
    }
}

// MARK: - Card layout persistence

extension CardLayout {

    /// One saved arrangement per style, so moving a block in Ticket doesn't disturb
    /// what was composed in Classic.
    private static func storeKey(_ style: CardStyle) -> String {
        "GiftWrap.cardLayout.\(style.rawValue)"
    }

    /// Where the single, style-less arrangement used to live.
    private static let legacyStoreKey = "GiftWrap.cardLayout"

    /// Bumped when a change makes saved positions wrong rather than merely different
    /// — a new type scale is one, since the defaults are budgeted around the sizes it
    /// produces. An older save is dropped for the current defaults.
    private static let storeVersion = 1

    private struct Stored: Codable {
        var version: Int
        var placements: [String: BlockPlacement]
    }

    static func load(_ style: CardStyle) -> CardLayout {
        migrateLegacyStore()

        guard let data = UserDefaults.standard.data(forKey: storeKey(style)),
              let stored = try? JSONDecoder().decode(Stored.self, from: data),
              stored.version == storeVersion
        else { return .defaults(for: style) }

        var layout = CardLayout.defaults(for: style)
        for block in CardBlock.allCases {
            if let p = stored.placements[block.rawValue] {
                layout[block] = BlockPlacement(
                    x: min(max(p.x, 0), 1),
                    y: min(max(p.y, 0), 1),
                    scale: p.scale > 0
                        ? min(max(p.scale, scaleRange.lowerBound), scaleRange.upperBound)
                        : 1
                )
            }
        }
        return layout
    }

    /// Saves the arrangement, or forgets it when nothing has been moved.
    ///
    /// Not storing the untouched case matters: switching styles saves the outgoing one,
    /// so merely visiting a style would otherwise pin whatever its defaults were that
    /// day, and a later correction to the design would never reach anyone who had looked.
    func save() {
        guard !isDefault else {
            UserDefaults.standard.removeObject(forKey: CardLayout.storeKey(style))
            return
        }
        let stored = Stored(version: CardLayout.storeVersion, placements: placements)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: CardLayout.storeKey(style))
    }

    /// An arrangement saved before styles existed was composed against what is now
    /// Classic, so that's where it belongs. Moved rather than copied, and only when
    /// Classic has nothing of its own to overwrite.
    private static func migrateLegacyStore() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: legacyStoreKey) else { return }
        if defaults.data(forKey: storeKey(.classic)) == nil {
            defaults.set(data, forKey: storeKey(.classic))
        }
        defaults.removeObject(forKey: legacyStoreKey)
    }
}

/// How the recipient gets the app.
enum GiftLinkKind: String, Codable, CaseIterable, Identifiable {
    /// Plain product page link — free apps, or paid apps the recipient buys themselves.
    case directLink
    /// App Store Connect promo code (free copy of a paid app, 100 per version, valid 4 weeks).
    case appPromoCode
    /// Offer code for a subscription or non-consumable In-App Purchase.
    case offerCode

    var id: String { rawValue }

    var label: String {
        switch self {
        case .directLink:   return T.kindDirectLink.text
        case .appPromoCode: return T.kindAppPromoCode.text
        case .offerCode:    return T.kindOfferCode.text
        }
    }

    var explanation: String {
        switch self {
        case .directLink:   return T.kindDirectLinkWhy.text
        case .appPromoCode: return T.kindAppPromoCodeWhy.text
        case .offerCode:    return T.kindOfferCodeWhy.text
        }
    }

    var requiresCode: Bool { self != .directLink }

    /// The `ctx` value Apple's redeem URL takes. Nil for the kind that carries no code
    /// and so has no redeem flow to name.
    var redeemContext: String? {
        switch self {
        case .directLink:   return nil
        case .appPromoCode: return "apps"
        case .offerCode:    return "offercodes"
        }
    }

    /// Whether this kind can carry an expiry date worth printing on the card.
    var hasExpiry: Bool { self != .directLink }
}

/// Everything the composer needs to render one card.
struct GiftDraft: Codable, Hashable {
    var app: AppStoreApp?
    var kind: GiftLinkKind = .directLink
    var code: String = ""
    var recipient: String = ""
    var sender: String = ""
    var message: String = ""
    /// Left empty on purpose: the card draws `C.defaultOccasion` in the card's own
    /// language when nothing has been typed, so the headline follows the language the
    /// sender picked instead of being frozen at whatever it was seeded with.
    var occasion: String = ""
    /// Which of the five card designs this gift is composed in.
    var style: CardStyle = .current
    /// The language the recipient reads — the card, the gift page, and the message that
    /// carries the link. A separate choice from the interface language, because a sender
    /// working in Korean may be sending to someone who doesn't.
    var cardLanguage: AppLanguage = .currentCard
    var theme: GiftTheme = .sunrise
    var expiry: Date? = nil
    var showCodeOnCard: Bool = true
    /// On by default. The gift page carries the QR through to the recipient, and a
    /// card opened on a laptop is exactly where scanning with a phone works — the
    /// case the printed card was always for.
    var showQRCode: Bool = true
    var providerToken: String = ""   // pt= campaign tracking
    var campaignCode: String = ""    // ct= campaign tracking

    var trimmedCode: String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    var isReady: Bool {
        guard app != nil else { return false }
        if kind.requiresCode { return !trimmedCode.isEmpty }
        return true
    }

    var redeemURL: URL? {
        guard let app else { return nil }
        return RedeemLinkBuilder.url(
            for: kind,
            appleID: app.id,
            code: trimmedCode,
            fallback: app.productURL,
            providerToken: providerToken,
            campaignCode: campaignCode
        )
    }
}

/// A record of one gift that was actually handed out, so codes are never sent twice.
struct GiftRecord: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var appName: String
    var appleID: Int
    var kind: GiftLinkKind
    var code: String
    var recipient: String
    var link: String
    var issuedAt: Date = Date()
    var expiry: Date?
    var note: String = ""
    var redeemed: Bool = false
}
