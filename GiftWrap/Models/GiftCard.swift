import Foundation
import CoreGraphics

// MARK: - Card layout

/// A piece of the card that can be placed on its own.
enum CardBlock: String, CaseIterable, Codable, Identifiable {
    case occasion, badge, logo, title, message, people, code, qr

    var id: String { rawValue }

    var label: String {
        switch self {
        case .occasion: return "머리말"
        case .badge:    return "받기 배지"
        case .logo:     return "앱 아이콘"
        case .title:    return "앱 이름"
        case .message:  return "메시지"
        case .people:   return "받는 · 보내는 사람"
        case .code:     return "코드"
        case .qr:       return "QR"
        }
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
/// Stored as fractions of `GiftCardView.canvas`. The defaults reproduce the composed
/// design — nothing moves until the user drags something.
struct CardLayout: Codable, Hashable {

    static let canvas = CGSize(width: 1000, height: 630)
    static let padding: CGFloat = 56
    static let scaleRange: ClosedRange<Double> = 0.4...2.5

    /// Keyed by `CardBlock.rawValue` — a plain string dictionary so the JSON stays
    /// readable and survives a block being added or renamed.
    private var placements: [String: BlockPlacement]

    init(placements: [String: BlockPlacement] = [:]) {
        self.placements = placements
    }

    /*
     * The default composition, in canvas points (1000 × 630, 56pt padding so
     * content runs 56…574 vertically):
     *
     *   occasion  56 … 78     badge   48 … 86  (top right)
     *   logo     130 …282     title  157 …256  (beside the logo)
     *   message  320 …449     code   470 …523  (right column)
     *   people   480 …563     qr     440 …562  (right column)
     */
    static let standard = CardLayout(placements: [
        CardBlock.occasion.rawValue: BlockPlacement(x: 0.0560, y: 0.0889),
        CardBlock.badge.rawValue:    BlockPlacement(x: 0.7670, y: 0.0762),
        CardBlock.logo.rawValue:     BlockPlacement(x: 0.0560, y: 0.2063),
        CardBlock.title.rawValue:    BlockPlacement(x: 0.2360, y: 0.2484),
        CardBlock.message.rawValue:  BlockPlacement(x: 0.0560, y: 0.5079),
        CardBlock.people.rawValue:   BlockPlacement(x: 0.0560, y: 0.7619),
        CardBlock.code.rawValue:     BlockPlacement(x: 0.5600, y: 0.7460),
        CardBlock.qr.rawValue:       BlockPlacement(x: 0.8060, y: 0.6984)
    ])

    subscript(block: CardBlock) -> BlockPlacement {
        get { placements[block.rawValue] ?? CardLayout.standard.placements[block.rawValue] ?? BlockPlacement(x: 0, y: 0) }
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

    var isStandard: Bool {
        CardBlock.allCases.allSatisfy { block in
            let a = self[block], b = CardLayout.standard[block]
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

    private static let storeKey = "GiftWrap.cardLayout"

    /// Bumped when a change makes saved positions wrong rather than merely different
    /// — a new type scale is one, since the defaults are budgeted around the sizes it
    /// produces. An older save is dropped for the current defaults.
    private static let storeVersion = 1

    private struct Stored: Codable {
        var version: Int
        var placements: [String: BlockPlacement]
    }

    static func load() -> CardLayout {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let stored = try? JSONDecoder().decode(Stored.self, from: data),
              stored.version == storeVersion
        else { return .standard }

        var layout = CardLayout.standard
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

    func save() {
        let stored = Stored(version: CardLayout.storeVersion, placements: placements)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: CardLayout.storeKey)
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
        case .directLink:   return "다운로드 링크"
        case .appPromoCode: return "앱 프로모션 코드"
        case .offerCode:    return "인앱 오퍼 코드"
        }
    }

    var explanation: String {
        switch self {
        case .directLink:
            return "코드 없이 App Store 제품 페이지로 보냅니다. 무료 앱에 적합합니다."
        case .appPromoCode:
            return "유료 앱을 무료로 받는 1회용 코드입니다. 생성 후 4주간 유효합니다."
        case .offerCode:
            return "구독·인앱 결제용 코드입니다. 앱이 무료 다운로드라면 이 방식을 씁니다."
        }
    }

    var requiresCode: Bool { self != .directLink }

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
    var occasion: String = "선물"
    var theme: GiftTheme = .sunrise
    var expiry: Date? = nil
    var showCodeOnCard: Bool = true
    var showQRCode: Bool = false
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
