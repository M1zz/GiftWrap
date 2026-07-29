import Foundation
import CoreGraphics

/// Builds the URLs Apple accepts for one-tap redemption.
///
///   Offer code (subscription / IAP):  https://apps.apple.com/redeem?ctx=offercodes&id={id}&code={code}
///   App promo code:                   https://apps.apple.com/redeem?ctx=apps&id={id}&code={code}
///   Product page:                     the trackViewUrl returned by the lookup API
///
/// If redemption fails on an older OS, the recipient can still paste the code into
/// App Store → profile → "기프트 카드 또는 코드 사용".
enum RedeemLinkBuilder {

    static func url(
        for kind: GiftLinkKind,
        appleID: Int,
        code: String,
        fallback: URL?,
        providerToken: String = "",
        campaignCode: String = ""
    ) -> URL? {
        let base: URL?
        switch kind {
        case .directLink:
            base = fallback ?? URL(string: "https://apps.apple.com/app/id\(appleID)")
        case .appPromoCode:
            base = redeemURL(context: "apps", appleID: appleID, code: code)
        case .offerCode:
            base = redeemURL(context: "offercodes", appleID: appleID, code: code)
        }
        guard let base else { return nil }
        return appendingCampaign(to: base, providerToken: providerToken, campaignCode: campaignCode)
    }

    private static func redeemURL(context: String, appleID: Int, code: String) -> URL? {
        guard !code.isEmpty else { return nil }
        var components = URLComponents(string: "https://apps.apple.com/redeem")
        components?.queryItems = [
            URLQueryItem(name: "ctx", value: context),
            URLQueryItem(name: "id", value: String(appleID)),
            URLQueryItem(name: "code", value: code)
        ]
        return components?.url
    }

    private static func appendingCampaign(to url: URL, providerToken: String, campaignCode: String) -> URL {
        let pt = providerToken.trimmingCharacters(in: .whitespaces)
        let ct = campaignCode.trimmingCharacters(in: .whitespaces)
        guard !pt.isEmpty || !ct.isEmpty,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return url }

        var items = components.queryItems ?? []
        if !pt.isEmpty { items.append(URLQueryItem(name: "pt", value: pt)) }
        if !ct.isEmpty { items.append(URLQueryItem(name: "ct", value: ct)) }
        components.queryItems = items
        return components.url ?? url
    }

    // MARK: - Reading a pasted link

    /// Everything a pasted string can tell us before the lookup runs.
    struct ParsedLink: Equatable {
        var appleID: Int
        /// Set only when the link spells it out (`ctx=offercodes` / `ctx=apps`).
        /// Nil means the caller has to infer it from the resolved app.
        var kind: GiftLinkKind?
        var code: String?
        var providerToken: String?
        var campaignCode: String?
    }

    /// Reads a redeem link, a product URL, an `itms-apps://` link, "id6501234567",
    /// or a bare number.
    ///
    ///   https://apps.apple.com/redeem?ctx=offercodes&id=6501234567&code=ABC123
    ///     → id 6501234567 · kind .offerCode · code "ABC123"
    ///
    /// A redeem link already states which kind of code it carries, so the composer
    /// shouldn't ask again.
    static func parse(_ input: String) -> ParsedLink? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let appleID = numericID(in: trimmed) else { return nil }

        var parsed = ParsedLink(appleID: appleID)
        for item in URLComponents(string: trimmed)?.queryItems ?? [] {
            let value = (item.value ?? "").trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { continue }
            switch item.name.lowercased() {
            case "ctx":  parsed.kind = kind(forContext: value)
            case "code": parsed.code = value.uppercased()
            case "pt":   parsed.providerToken = value
            case "ct":   parsed.campaignCode = value
            default:     break
            }
        }
        return parsed
    }

    /// Picks the kind when the link didn't say. A paid app can only carry a promo code;
    /// a free app carries an offer code if there's a code at all, otherwise it's just a link.
    static func inferredKind(explicit: GiftLinkKind?, isFree: Bool, hasCode: Bool) -> GiftLinkKind {
        if let explicit { return explicit }
        if !isFree { return .appPromoCode }
        return hasCode ? .offerCode : .directLink
    }

    /// Pulls the numeric Apple ID out of anything the user pastes.
    static func appleID(from input: String) -> Int? {
        parse(input)?.appleID
    }

    private static func kind(forContext context: String) -> GiftLinkKind? {
        switch context.lowercased() {
        case "offercodes": return .offerCode
        case "apps":       return .appPromoCode
        default:           return nil
        }
    }

    private static func numericID(in text: String) -> Int? {
        if let direct = Int(text) { return direct }

        // A redeem link carries it as a query item — read that before touching the path,
        // so an app slug that happens to contain "id123456" can't win.
        if let value = URLComponents(string: text)?
            .queryItems?
            .first(where: { $0.name.lowercased() == "id" })?
            .value,
           let id = Int(value.trimmingCharacters(in: .whitespaces)) {
            return id
        }

        // "/id6501234567" in a product path, then anything else shaped like an ID.
        for pattern in ["/id(\\d{5,})", "\\bid=?(\\d{5,})"] {
            if let id = firstCapture(of: pattern, in: text) { return id }
        }
        return nil
    }

    private static func firstCapture(of pattern: String, in text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let digits = Range(match.range(at: 1), in: text)
        else { return nil }
        return Int(text[digits])
    }
}

// MARK: - Gift page link

/// Builds the URL for `web/gift.html` — the page that wraps the gift, plays the
/// unwrapping, and only then hands over the redeem button.
///
/// Everything the page needs rides in the URL **fragment**, not the query string.
/// A fragment is never sent to the server, so the redeem code and the recipient's
/// name stay out of access logs, referrers and any proxy in between. It also means
/// the page itself stays a static file: one upload serves every gift.
enum GiftLinkBuilder {

    /// Where the page is served from. A constant rather than a setting: it's the copy
    /// published from this repo's `gh-pages` branch, and asking for it every time would
    /// be asking the user to type back something we already know. Hosting it elsewhere
    /// is a one-line change here.
    static let pageURL = "https://m1zz.github.io/GiftWrap/gift.html"

    /// Short keys — this ends up in a chat message, so the URL shouldn't be a wall.
    struct Payload: Codable, Equatable {
        var v = 1
        var n: String?          // app name
        var d: String?          // developer
        var i: String?          // icon URL
        var u: String?          // redeem URL
        var p: String?          // product page, for "앱 열기" afterwards
        var c: String?          // code, for the manual fallback
        var o: String?          // headline (the occasion line)
        var m: String?          // message
        var f: String?          // from
        var r: String?          // to
        var e: String?          // expiry, yyyy-MM-dd
        var g: [String]?        // gradient stops, hex without '#'
        var b: [String]?        // bloom colours
        var q: Bool?            // draw the QR block
        var k: Bool?            // draw the code chip on the card
        /// Block id → [x, y, scale, width, height]. The arrangement from the composer,
        /// so the page draws the card that was designed rather than one of its own.
        /// Width and height are the footprint the block actually took in the preview,
        /// in canvas points — the page renders in different fonts and would otherwise
        /// run one block into the next. They're omitted when nothing measured it.
        var l: [String: [Double]]?
        /// A rendered card image, if one is hosted somewhere. The page prefers it over
        /// redrawing. Left nil by default: the PNG is too big for a link, and putting
        /// it on a public URL would leak the recipient's name and message — the very
        /// thing the fragment exists to avoid.
        var img: String?
    }

    static func payload(
        for draft: GiftDraft,
        layout: CardLayout = .standard,
        sizes: [String: CGSize] = [:]
    ) -> Payload {
        var payload = Payload()
        payload.n = draft.app?.name
        payload.d = nonEmpty(draft.app?.developer)
        payload.i = draft.app?.artworkURL?.absoluteString
        payload.u = draft.redeemURL?.absoluteString
        payload.p = draft.app?.productURL?.absoluteString
        payload.c = draft.kind.requiresCode ? nonEmpty(draft.trimmedCode) : nil
        payload.o = nonEmpty(draft.occasion) ?? "선물"
        payload.m = nonEmpty(draft.message)
        payload.f = nonEmpty(draft.sender)
        payload.r = nonEmpty(draft.recipient)
        payload.g = draft.theme.hexStops.map(stripHash)
        payload.b = draft.theme.hexBlooms.map(stripHash)

        payload.q = draft.showQRCode && draft.redeemURL != nil
        payload.k = draft.showCodeOnCard && draft.kind.requiresCode && !draft.trimmedCode.isEmpty

        // Rounded hard — four decimals is finer than a pixel on a 1000pt card, and it
        // keeps the link from doubling in length.
        var blocks: [String: [Double]] = [:]
        for block in CardBlock.allCases {
            let placement = layout[block]
            var values = [round(placement.x), round(placement.y), round(placement.scale)]
            if let size = sizes[block.rawValue], size.width > 0, size.height > 0 {
                values.append(contentsOf: [
                    round(Double(size.width)), round(Double(size.height))
                ])
            }
            blocks[block.rawValue] = values
        }
        payload.l = blocks

        if let expiry = draft.expiry, draft.kind.hasExpiry {
            payload.e = isoDay.string(from: expiry)
        }
        return payload
    }

    private static func round(_ value: Double) -> Double {
        (value * 10_000).rounded() / 10_000
    }

    /// `<pageURL>#<base64url payload>`, or nil until an app has been resolved.
    static func url(
        for draft: GiftDraft,
        base: String = GiftLinkBuilder.pageURL,
        layout: CardLayout = .standard,
        sizes: [String: CGSize] = [:]
    ) -> URL? {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, draft.app != nil else { return nil }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        guard let data = try? encoder.encode(payload(for: draft, layout: layout, sizes: sizes))
        else { return nil }

        // Strip any fragment the base already carries, then append our own.
        let stem = trimmed.split(separator: "#", maxSplits: 1).first.map(String.init) ?? trimmed
        return URL(string: stem + "#" + base64url(data))
    }

    static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func stripHash(_ hex: String) -> String {
        hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    }

    private static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
