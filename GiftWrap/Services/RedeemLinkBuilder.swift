import Foundation

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

    /// Pulls the numeric Apple ID out of anything the user pastes:
    /// a full product URL (".../id6501234567"), a redeem link ("?ctx=offercodes&id=6501234567&code=…"),
    /// "id6501234567", or the bare number.
    static func appleID(from input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = Int(trimmed) { return direct }

        // "id6501234567" in a product path, or "id=6501234567" in a redeem query.
        let pattern = "id=?(\\d{5,})"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: range),
              let digits = Range(match.range(at: 1), in: trimmed)
        else { return nil }
        return Int(trimmed[digits])
    }
}
