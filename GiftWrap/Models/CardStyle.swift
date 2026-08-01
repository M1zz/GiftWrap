import Foundation
import CoreGraphics

/// One of five card designs.
///
/// A style is two things at once: where the blocks start out, and how the card is drawn
/// around them. Colour is a separate axis — every style works in every `GiftTheme`, so
/// the two pickers multiply rather than overlap.
///
/// The positions here are budgeted the same way `classic`'s always were: on the
/// 1000 × 630 canvas, against the heights the blocks actually measure at that style's
/// type scale. Change a scale and its placements have to be re-checked, which the
/// editor's overlap banner will tell you about immediately.
enum CardStyle: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {

    /// Left-aligned, icon beside the app name. The design this app started with.
    case classic
    /// One centred column, with the code and QR settled into the bottom corners.
    case centered
    /// A tear-off stub down the right, holding the QR and the code.
    case ticket
    /// The headline takes over the card; the icon shrinks out of its way.
    case poster
    /// Wide margins, small type, almost no ornament.
    case minimal

    var id: String { rawValue }

    // MARK: - The last one chosen

    private static let storeKey = "GiftWrap.cardStyle"

    /// The design the composer opens in.
    ///
    /// Remembered for the same reason the arrangement within a style is: picking a
    /// design is a decision about how your cards look, not about this one card, and
    /// having it reset to Classic every launch would make it feel like neither.
    static var current: CardStyle {
        guard let raw = UserDefaults.standard.string(forKey: storeKey),
              let style = CardStyle(rawValue: raw)
        else { return .classic }
        return style
    }

    static func persist(_ style: CardStyle) {
        UserDefaults.standard.set(style.rawValue, forKey: storeKey)
    }

    var label: Loc {
        switch self {
        case .classic:  return Loc(ko: "클래식", en: "Classic")
        case .centered: return Loc(ko: "센터", en: "Centered")
        case .ticket:   return Loc(ko: "티켓", en: "Ticket")
        case .poster:   return Loc(ko: "포스터", en: "Poster")
        case .minimal:  return Loc(ko: "미니멀", en: "Minimal")
        }
    }

    // MARK: - Chrome

    /// Corner rounding, in canvas points. Harder corners read as something you were
    /// handed; softer ones as something on a screen.
    var cornerRadius: CGFloat {
        switch self {
        case .classic, .centered, .poster: return 56
        case .ticket:                      return 28
        case .minimal:                     return 44
        }
    }

    /// Multiplies `GiftCardView.typeScale` for every piece of text on the card.
    var typeScale: CGFloat {
        self == .minimal ? 0.88 : 1
    }

    /// An extra multiplier for the headline alone — the whole point of `poster`. It has
    /// to clear the app name by a wide margin (44pt at the base scale) or the card just
    /// looks like it has two titles.
    var headlineScale: CGFloat {
        self == .poster ? 5.0 : 1
    }

    /// How wide the text blocks are allowed to run, in canvas points.
    ///
    /// These are the blocks that take a width rather than hugging their text, so the
    /// number here *is* the box the editor hit-tests and the collision check measures.
    /// Ticket has to keep them out of the stub; centred makes them full-width columns
    /// so that centring the text inside actually centres it on the card.
    var titleMaxWidth: CGFloat {
        switch self {
        case .ticket:   return 430   // stops short of the perforation at 700
        case .centered: return 640   // a column centred by its placement, at x 0.18
        default:        return 640
        }
    }

    var messageMaxWidth: CGFloat {
        switch self {
        case .ticket:   return 600
        case .centered: return 700   // centred by its placement, at x 0.15
        default:        return 700
        }
    }

    /// A ceiling for the headline, so a long one wraps instead of running off the card.
    /// Only poster needs it; at 88pt two words already fill the width.
    var headlineMaxWidth: CGFloat? {
        self == .poster ? 760 : nil
    }

    /// The diagonal highlight a laminated card catches. Minimal doesn't catch any.
    var sheenOpacity: Double {
        switch self {
        case .minimal: return 0
        case .ticket:  return 0.18
        case .poster:  return 0.30
        default:       return 0.26
        }
    }

    /// How strongly the soft colour blooms show through the gradient.
    var bloomOpacity: Double {
        self == .minimal ? 0.22 : 1
    }

    /// A hairline inset frame, the way a printed card is often bordered.
    var hasFrame: Bool { self == .minimal }

    /// The dashed line and the two notches that make a stub.
    var hasPerforation: Bool { self == .ticket }

    /// Where the stub starts, as a fraction of the card's width.
    static let perforationX: Double = 0.70

    /// Whether the headline, app name and message are centred on themselves.
    var centersText: Bool { self == .centered }

    // MARK: - Where the blocks start

    /// The arrangement this style opens with. Dragging edits a copy of it, saved per
    /// style, so switching styles doesn't drag one style's layout into another's design.
    var defaultPlacements: [String: BlockPlacement] {
        switch self {

        /*
         * classic — the original composition, in canvas points:
         *   occasion  56 … 78     badge   48 … 86  (top right)
         *   logo     130 …282     title  157 …256  (beside the logo)
         *   message  320 …449     code   470 …523  (right column)
         *   people   480 …563     qr     440 …562  (right column)
         */
        case .classic:
            return [
                CardBlock.occasion.rawValue: BlockPlacement(x: 0.0560, y: 0.0889),
                CardBlock.badge.rawValue:    BlockPlacement(x: 0.7670, y: 0.0762),
                CardBlock.logo.rawValue:     BlockPlacement(x: 0.0560, y: 0.2063),
                CardBlock.title.rawValue:    BlockPlacement(x: 0.2360, y: 0.2484),
                CardBlock.message.rawValue:  BlockPlacement(x: 0.0560, y: 0.5079),
                CardBlock.people.rawValue:   BlockPlacement(x: 0.0560, y: 0.7619),
                CardBlock.code.rawValue:     BlockPlacement(x: 0.5600, y: 0.7460),
                CardBlock.qr.rawValue:       BlockPlacement(x: 0.8060, y: 0.6984)
            ]

        /*
         * centered — a column down the middle, with the utilities in the corners:
         *   occasion  56 … 78     logo    96 …248
         *   title    262 …361     message 376 …466
         *   code     478 …525     people 490 …573 (left)   qr 452 …574 (right)
         *
         * Title and message are centred as boxes — 640 and 700 wide, placed at
         * (1000 − width) / 2 — so the text centred inside them lands on the card's
         * middle whatever it says. The blocks that hug their own text can't do that;
         * their x assumes a usual length and drifts a little on an unusual one.
         */
        case .centered:
            return [
                CardBlock.occasion.rawValue: BlockPlacement(x: 0.4550, y: 0.0889),
                CardBlock.badge.rawValue:    BlockPlacement(x: 0.7670, y: 0.0762),
                CardBlock.logo.rawValue:     BlockPlacement(x: 0.4240, y: 0.1524),
                CardBlock.title.rawValue:    BlockPlacement(x: 0.1800, y: 0.4159),
                CardBlock.message.rawValue:  BlockPlacement(x: 0.1500, y: 0.5968),
                CardBlock.code.rawValue:     BlockPlacement(x: 0.4000, y: 0.7587),
                CardBlock.people.rawValue:   BlockPlacement(x: 0.0560, y: 0.7778),
                CardBlock.qr.rawValue:       BlockPlacement(x: 0.8220, y: 0.7175)
            ]

        /*
         * ticket — everything lives left of the perforation at x 700, except the two
         * things you actually hand over, which sit in the stub:
         *   left   occasion 56…78 · logo 130…282 · title 157…256 · message 330…450 · people 480…563
         *   stub   qr 180…302 · code 330…377
         */
        case .ticket:
            return [
                CardBlock.occasion.rawValue: BlockPlacement(x: 0.0560, y: 0.0889),
                CardBlock.badge.rawValue:    BlockPlacement(x: 0.4600, y: 0.0762),
                CardBlock.logo.rawValue:     BlockPlacement(x: 0.0560, y: 0.2063),
                CardBlock.title.rawValue:    BlockPlacement(x: 0.2360, y: 0.2484),
                CardBlock.message.rawValue:  BlockPlacement(x: 0.0560, y: 0.5238),
                CardBlock.people.rawValue:   BlockPlacement(x: 0.0560, y: 0.7619),
                CardBlock.qr.rawValue:       BlockPlacement(x: 0.7890, y: 0.2857),
                CardBlock.code.rawValue:     BlockPlacement(x: 0.7500, y: 0.5238)
            ]

        /*
         * poster — the headline is the card. The icon drops to 55% and moves out of
         * the way so the type has the width. Budgeted around a headline at 88pt,
         * which draws about 106 tall:
         *   logo 56…140 (small) · occasion 160…266 (huge) · title 290…389
         *   message 405…475 · people 490…573 · code 470…517 · qr 440…562
         */
        case .poster:
            return [
                CardBlock.logo.rawValue:     BlockPlacement(x: 0.0560, y: 0.0889, scale: 0.55),
                CardBlock.badge.rawValue:    BlockPlacement(x: 0.7670, y: 0.0984),
                CardBlock.occasion.rawValue: BlockPlacement(x: 0.0560, y: 0.2540),
                CardBlock.title.rawValue:    BlockPlacement(x: 0.0560, y: 0.4603),
                CardBlock.message.rawValue:  BlockPlacement(x: 0.0560, y: 0.6429),
                CardBlock.people.rawValue:   BlockPlacement(x: 0.0560, y: 0.7778),
                CardBlock.code.rawValue:     BlockPlacement(x: 0.5600, y: 0.7460),
                CardBlock.qr.rawValue:       BlockPlacement(x: 0.8060, y: 0.6984)
            ]

        /*
         * minimal — a 90pt margin instead of 56, type at 88%, and a stack with air
         * between the pieces:
         *   occasion 90…109 · logo 140…254 (75%) · title 276…363
         *   message 385…465 · people 480…553 · code 470…514 · qr 440…562
         */
        case .minimal:
            return [
                CardBlock.occasion.rawValue: BlockPlacement(x: 0.0900, y: 0.1429),
                CardBlock.badge.rawValue:    BlockPlacement(x: 0.7500, y: 0.0952),
                CardBlock.logo.rawValue:     BlockPlacement(x: 0.0900, y: 0.2222, scale: 0.75),
                CardBlock.title.rawValue:    BlockPlacement(x: 0.0900, y: 0.4381),
                CardBlock.message.rawValue:  BlockPlacement(x: 0.0900, y: 0.6111),
                CardBlock.people.rawValue:   BlockPlacement(x: 0.0900, y: 0.7619),
                CardBlock.code.rawValue:     BlockPlacement(x: 0.5600, y: 0.7460),
                CardBlock.qr.rawValue:       BlockPlacement(x: 0.8100, y: 0.6984)
            ]
        }
    }
}
