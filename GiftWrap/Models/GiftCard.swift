import Foundation

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
