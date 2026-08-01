import Foundation

// MARK: - Language

/// The two languages the app speaks.
///
/// Two of them are chosen from, not looked up: the app is small enough that a pair of
/// hand-written strings per label reads better than a `.strings` file, and — the reason
/// that decided it — a table in Swift can be switched while the app is running.
/// `Localizable.strings` is bound to the bundle Cocoa picked at launch, so an in-app
/// language menu backed by it would need a relaunch to take effect.
enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case korean = "ko"
    case english = "en"

    var id: String { rawValue }

    /// Each language in its own words, so the menu is readable to whoever needs it.
    var displayName: String {
        switch self {
        case .korean:  return "한국어"
        case .english: return "English"
        }
    }

    /// What goes in `<html lang>` on the pages this app writes.
    var htmlLang: String { rawValue }

    /// The locale the recipient-facing dates are formatted in.
    var locale: Locale {
        switch self {
        case .korean:  return Locale(identifier: "ko_KR")
        case .english: return Locale(identifier: "en_US")
        }
    }

    // MARK: Where the first choice comes from

    private static let storeKey = "GiftWrap.language"

    /// Korean only if the system actually asks for it — anything else gets English,
    /// which is the safer guess for a language we don't have a table for.
    static var systemDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("ko") ? .korean : .english
    }

    /// The chosen language, readable from anywhere.
    ///
    /// `Localization` owns the published copy for SwiftUI; this reads the same
    /// UserDefaults value so the pieces that aren't views — thrown errors, the
    /// exporters — can localize without hopping to the main actor.
    static var current: AppLanguage {
        guard let raw = UserDefaults.standard.string(forKey: storeKey),
              let language = AppLanguage(rawValue: raw)
        else { return systemDefault }
        return language
    }

    static func persist(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: storeKey)
    }
}

/// One label in both languages.
///
/// Held as a value rather than a lookup key so that a missing translation is a compile
/// error instead of a string that falls through to its own key at runtime.
struct Loc: Sendable {
    let ko: String
    let en: String

    init(ko: String, en: String) {
        self.ko = ko
        self.en = en
    }

    func text(_ language: AppLanguage) -> String {
        switch language {
        case .korean:  return ko
        case .english: return en
        }
    }

    /// The chosen language's copy, for the places that have no view to ask.
    var text: String { text(.current) }
}

/// The language the interface is drawn in.
///
/// Views observe this, so switching redraws them; the card's own language is a separate
/// choice that lives on the draft, because the sender picks it for the recipient.
@MainActor
final class Localization: ObservableObject {

    static let shared = Localization()

    @Published var language: AppLanguage {
        didSet { AppLanguage.persist(language) }
    }

    private init() {
        language = .current
    }

    /// The interface copy of a label.
    func s(_ loc: Loc) -> String { loc.text(language) }
}

// MARK: - Interface strings

/// Everything the operator of this app reads.
enum T {

    // Tabs
    static let composerTab = Loc(ko: "카드 만들기", en: "Compose")
    static let batchTab     = Loc(ko: "여러 장 만들기", en: "Batch")
    static let ledgerTab    = Loc(ko: "보낸 기록", en: "Sent")

    // App menu
    static let languageMenu = Loc(ko: "언어", en: "Language")

    // MARK: App section

    static let appSection    = Loc(ko: "앱", en: "App")
    static let appQueryField = Loc(ko: "App Store 링크 또는 ID", en: "App Store link or ID")
    static let lookUp        = Loc(ko: "불러오기", en: "Look up")
    static let storefront    = Loc(ko: "스토어프론트", en: "Storefront")
    static let storeKR       = Loc(ko: "한국 (kr)", en: "Korea (kr)")
    static let storeUS       = Loc(ko: "미국 (us)", en: "United States (us)")
    static let storeJP       = Loc(ko: "일본 (jp)", en: "Japan (jp)")
    static let storeGB       = Loc(ko: "영국 (gb)", en: "United Kingdom (gb)")
    static let resolved      = Loc(ko: "확인됨", en: "Resolved")
    static let free          = Loc(ko: "무료", en: "Free")

    // MARK: Delivery section

    static let deliverySection = Loc(ko: "전달 방식", en: "Delivery")
    static let deliveryKind    = Loc(ko: "방식", en: "Method")
    static let codeField       = Loc(ko: "코드", en: "Code")
    static let codeAlreadySent = Loc(ko: "이미 보낸 코드입니다.", en: "This code has already been sent.")
    static let showExpiry      = Loc(ko: "만료일 표시", en: "Show an expiry date")
    static let expiryField     = Loc(ko: "만료일", en: "Expires")

    // MARK: Card section

    static let cardSection   = Loc(ko: "카드", en: "Card")
    static let cardStyle     = Loc(ko: "디자인", en: "Design")
    static let cardStyleHint = Loc(
        ko: "스타일마다 배치를 따로 기억합니다. 옮겨 둔 배치는 그대로 남아요.",
        en: "Each style remembers its own arrangement, so what you dragged stays put."
    )
    static let cardLanguage  = Loc(ko: "카드 언어", en: "Card language")
    static let cardLanguageHint = Loc(
        ko: "받는 사람이 보는 카드·선물 페이지·전송 문구의 언어입니다.",
        en: "The language of the card, the gift page and the message the recipient gets."
    )
    static let occasionField = Loc(ko: "문구 (예: 생일 축하해요)", en: "Headline (e.g. Happy birthday)")
    static let recipient     = Loc(ko: "받는 사람", en: "To")
    static let sender        = Loc(ko: "보내는 사람", en: "From")
    static let message       = Loc(ko: "메시지", en: "Message")
    static let messageLimit  = Loc(ko: "세 줄까지 카드에 들어갑니다.", en: "Up to three lines fit on the card.")
    static let colour        = Loc(ko: "색상", en: "Colour")
    static let showCode      = Loc(ko: "카드에 코드 표시", en: "Show the code on the card")
    static let showQR        = Loc(ko: "QR 코드 넣기", en: "Include a QR code")

    // MARK: Campaign tracking

    static let campaignGroup = Loc(ko: "캠페인 추적 (선택)", en: "Campaign tracking (optional)")
    static let campaignHint  = Loc(
        ko: "App Analytics에서 유입을 구분하고 싶을 때만 채우세요.",
        en: "Fill these in only to tell the traffic apart in App Analytics."
    )

    // MARK: Layout bar

    static let resetLayout = Loc(ko: "배치 초기화", en: "Reset layout")
    static let layoutIdle  = Loc(
        ko: "카드 위의 요소를 끌어서 옮겨 보세요. PNG로 내보낼 때도 그대로 나갑니다.",
        en: "Drag the pieces of the card around. The exported PNG keeps whatever you arrange."
    )
    static let layoutChanged = Loc(
        ko: "배치를 바꿨습니다. 내보내는 이미지에도 그대로 적용됩니다.",
        en: "You've changed the arrangement. The exported image keeps it."
    )
    static func layoutSelected(_ block: String) -> Loc {
        Loc(
            ko: "\(block) 선택됨 — 끌어서 이동(방향키 미세 조정), 모서리 손잡이나 +/− 키로 크기 조절",
            en: "\(block) selected — drag to move (arrow keys to nudge), resize with the corner grip or +/−"
        )
    }

    // MARK: Collision banner

    static func collisionOne(_ a: String, _ b: String) -> Loc {
        Loc(ko: "\(a)과 \(b)가 겹칩니다", en: "\(a) and \(b) overlap")
    }
    static func collisionMany(_ a: String, _ b: String, count: Int) -> Loc {
        Loc(
            ko: "\(a)과 \(b)를 비롯해 \(count)곳이 겹칩니다",
            en: "\(a) and \(b), and \(count) places in all, overlap"
        )
    }
    static let collisionExported = Loc(
        ko: "내보내는 이미지에도 그대로 나갑니다",
        en: "The exported image keeps it"
    )
    static let resetColliding = Loc(ko: "겹친 것만 되돌리기", en: "Undo just the overlap")

    // MARK: Action bar

    static let open            = Loc(ko: "열기", en: "Open")
    static let share           = Loc(ko: "공유", en: "Share")
    static let copyMessage     = Loc(ko: "문구 복사", en: "Copy message")
    static let copyImage       = Loc(ko: "이미지 복사", en: "Copy image")
    static let previewReceived = Loc(ko: "받는 화면 미리보기", en: "Preview what they see")
    static let savePNG         = Loc(ko: "PNG 저장", en: "Save PNG")
    static let saveHTML        = Loc(ko: "낱장 HTML 저장", en: "Save standalone HTML")
    static let addToLedger     = Loc(ko: "보낸 기록에 추가", en: "Add to sent")

    static let copyLinkHeading = Loc(ko: "링크 복사", en: "Copy a link")
    static let copyGiftLink    = Loc(ko: "선물 페이지 링크 복사", en: "Copy the gift page link")
    static let copyGiftLinkSub = Loc(ko: "카드가 먼저 열리는 선물 페이지", en: "The page that unwraps the card first")
    static let copyRedeemLink  = Loc(ko: "프로모션 링크만 복사", en: "Copy the redeem link only")
    static let copyRedeemLinkSub = Loc(ko: "App Store로 바로 가는 원본 링크", en: "The raw link straight to the App Store")

    // MARK: Status messages

    static func loaded(_ name: String) -> Loc {
        Loc(ko: "\(name) 불러왔습니다.", en: "Loaded \(name).")
    }
    static let layoutReset = Loc(
        ko: "카드 배치를 기본값으로 되돌렸습니다.",
        en: "Put the card's arrangement back to the default."
    )
    static let copiedRedeemLink = Loc(
        ko: "프로모션 링크를 복사했습니다 — App Store로 바로 갑니다.",
        en: "Copied the redeem link — it goes straight to the App Store."
    )
    static let copiedMessage = Loc(
        ko: "메시지를 복사했습니다 — 카드 이미지도 함께 보내세요.",
        en: "Copied the message — send the card image with it."
    )
    static let sharing = Loc(
        ko: "선물 링크와 카드 이미지를 함께 공유합니다.",
        en: "Sharing the gift link and the card image together."
    )
    static let copiedGiftLink = Loc(
        ko: "선물 페이지 링크를 복사했습니다 — 카드부터 열립니다.",
        en: "Copied the gift page link — the card opens first."
    )
    static let copiedImage = Loc(ko: "카드 이미지를 복사했습니다.", en: "Copied the card image.")
    static func savedFile(_ name: String) -> Loc {
        Loc(ko: "저장했습니다 — \(name)", en: "Saved — \(name)")
    }
    static func savedGiftPage(_ name: String) -> Loc {
        Loc(ko: "선물 페이지를 저장했습니다 — \(name)", en: "Saved the gift page — \(name)")
    }
    static let recordedInLedger = Loc(ko: "보낸 기록에 추가했습니다.", en: "Added to the sent list.")
    static func exportedCount(_ count: Int) -> Loc {
        Loc(ko: "\(count)장 내보냈습니다.", en: "Exported \(count) cards.")
    }

    /// What a pasted link filled in on its own.
    static func autoFilled(_ parts: String) -> Loc {
        Loc(ko: "링크에서 \(parts) 자동 설정", en: "Set \(parts) from the link")
    }

    // MARK: Batch

    static let batchCodeList = Loc(ko: "코드 목록", en: "Codes")
    static let batchHint = Loc(
        ko: "한 줄에 하나씩. 받는 사람을 함께 적으려면 `코드, 이름` 형식으로 쓰세요.",
        en: "One per line. To name a recipient too, write `CODE, name`."
    )
    static let batchNeedsApp = Loc(
        ko: "먼저 ‘카드 만들기’ 탭에서 앱을 불러오세요.",
        en: "Look an app up on the Compose tab first."
    )
    static func batchRecognised(_ count: Int) -> Loc {
        Loc(ko: "\(count)개 인식됨", en: "\(count) recognised")
    }
    static let batchExport = Loc(ko: "폴더로 내보내기", en: "Export to a folder")
    static let batchPreview = Loc(ko: "미리보기", en: "Preview")
    static let batchPreviewNote = Loc(
        ko: "카드 색상·문구·메시지는 ‘카드 만들기’ 탭 설정을 그대로 씁니다. 코드와 받는 사람만 줄마다 달라집니다.",
        en: "Colour, headline and message come from the Compose tab. Only the code and the recipient change line by line."
    )
    static let batchNeedsCodes = Loc(
        ko: "코드를 한 줄에 하나씩 넣어주세요.",
        en: "Put one code on each line."
    )

    // MARK: Ledger

    static let ledgerEmptyTitle = Loc(ko: "아직 보낸 선물이 없습니다.", en: "Nothing sent yet.")
    static let ledgerEmptyBody = Loc(
        ko: "카드를 만든 뒤 ‘보낸 기록에 추가’를 누르면 여기에 쌓입니다.",
        en: "Make a card, press Add to sent, and it lands here."
    )
    static let ledgerDate     = Loc(ko: "보낸 날짜", en: "Sent")
    static let ledgerApp      = Loc(ko: "앱", en: "App")
    static let ledgerKind     = Loc(ko: "방식", en: "Method")
    static let ledgerRedeemed = Loc(ko: "사용됨", en: "Redeemed")
    static let ledgerCopyLink = Loc(ko: "링크 복사", en: "Copy link")
    static let search         = Loc(ko: "검색", en: "Search")
    static func ledgerCount(_ count: Int) -> Loc {
        Loc(ko: "\(count)건", en: count == 1 ? "1 gift" : "\(count) gifts")
    }
    static let exportCSV = Loc(ko: "CSV 내보내기", en: "Export CSV")

    // MARK: Blocks

    static let blockOccasion = Loc(ko: "머리말", en: "Headline")
    static let blockBadge    = Loc(ko: "받기 배지", en: "Badge")
    static let blockLogo     = Loc(ko: "앱 아이콘", en: "App icon")
    static let blockTitle    = Loc(ko: "앱 이름", en: "App name")
    static let blockMessage  = Loc(ko: "메시지", en: "Message")
    static let blockPeople   = Loc(ko: "받는 · 보내는 사람", en: "To · From")
    static let blockCode     = Loc(ko: "코드", en: "Code")
    static let blockQR       = Loc(ko: "QR", en: "QR")

    // MARK: Delivery kinds

    static let kindDirectLink   = Loc(ko: "다운로드 링크", en: "Download link")
    static let kindAppPromoCode = Loc(ko: "앱 프로모션 코드", en: "App promo code")
    static let kindOfferCode    = Loc(ko: "인앱 오퍼 코드", en: "In-app offer code")

    static let kindDirectLinkWhy = Loc(
        ko: "코드 없이 App Store 제품 페이지로 보냅니다. 무료 앱에 적합합니다.",
        en: "Sends them to the App Store product page, no code involved. Right for a free app."
    )
    static let kindAppPromoCodeWhy = Loc(
        ko: "유료 앱을 무료로 받는 1회용 코드입니다. 생성 후 4주간 유효합니다.",
        en: "A single-use code for a free copy of a paid app. Valid for four weeks after it's made."
    )
    static let kindOfferCodeWhy = Loc(
        ko: "구독·인앱 결제용 코드입니다. 앱이 무료 다운로드라면 이 방식을 씁니다.",
        en: "A code for a subscription or in-app purchase. Use this when the app itself is a free download."
    )

    // MARK: Panels and errors

    static let chooseFolder = Loc(ko: "이 폴더에 저장", en: "Save here")

    static let lookupBadInput = Loc(
        ko: "App Store 링크나 숫자 ID를 넣어주세요.",
        en: "Enter an App Store link or a numeric ID."
    )
    static let lookupNotFound = Loc(
        ko: "해당 스토어프론트에서 앱을 찾지 못했습니다. 국가 코드를 확인해 주세요.",
        en: "No app found in that storefront. Check the country code."
    )
    static func lookupNetwork(_ message: String) -> Loc {
        Loc(
            ko: "앱 정보를 불러오지 못했습니다. \(message)",
            en: "Couldn't load the app's details. \(message)"
        )
    }
}

// MARK: - Recipient-facing strings

/// What the person receiving the gift reads — on the card, on the gift page, and in the
/// message that carries the link. Resolved against `GiftDraft.cardLanguage`, never the
/// interface language: a Korean sender may well be sending to someone who reads English.
enum C {

    static let defaultOccasion = Loc(ko: "선물", en: "GIFT")
    static let badge           = Loc(ko: "App Store에서 받기", en: "Get it on the App Store")
    static let placeholderApp  = Loc(ko: "앱을 불러오세요", en: "Look up an app")
    static let placeholderDev  = Loc(ko: "개발자", en: "Developer")

    static func to(_ name: String) -> Loc {
        Loc(ko: "To. \(name)", en: "To. \(name)")
    }
    static func from(_ name: String) -> Loc {
        Loc(ko: "From. \(name)", en: "From. \(name)")
    }

    /// The date the card prints under the names.
    static func validUntil(_ date: Date) -> Loc {
        Loc(ko: "\(day(date, .korean))까지", en: "Valid through \(day(date, .english))")
    }

    /// The same date, as the gift page and the message say it.
    static func usableUntil(_ date: Date) -> Loc {
        Loc(
            ko: "\(day(date, .korean))까지 사용할 수 있어요.",
            en: "You can use it through \(day(date, .english))."
        )
    }

    // MARK: The message that carries the link

    static func toHonorific(_ name: String) -> Loc {
        Loc(ko: "\(name)님께", en: "For \(name)")
    }
    static let giftArrived = Loc(ko: "🎁 선물이 도착했어요", en: "🎁 A gift has arrived for you")
    static func codeLine(_ code: String) -> Loc {
        Loc(ko: "코드: \(code)", en: "Code: \(code)")
    }
    static let manualRedeem = Loc(
        ko: "링크가 열리지 않으면 App Store → 프로필 → ‘기프트 카드 또는 코드 사용’에 입력하세요.",
        en: "If the link doesn't open, go to App Store → your profile → Redeem Gift Card or Code and enter it."
    )

    // MARK: The standalone HTML page

    static let openInStore = Loc(ko: "App Store에서 받기", en: "Get it on the App Store")
    static let copyCode    = Loc(ko: "코드 복사", en: "Copy code")
    static let copiedCode  = Loc(ko: "복사됨", en: "Copied")
    static let manualRedeemShort = Loc(
        ko: "버튼이 열리지 않으면 App Store → 프로필 → ‘기프트 카드 또는 코드 사용’에 코드를 입력하세요.",
        en: "If the button doesn't open, go to App Store → your profile → Redeem Gift Card or Code and enter the code."
    )
    static func pageDescription(_ appName: String) -> Loc {
        Loc(ko: "\(appName) 받기", en: "Get \(appName)")
    }
    static func sharedTitle(_ sender: String, _ occasion: String) -> Loc {
        Loc(ko: "\(sender)님이 보낸 \(occasion)", en: "\(occasion) from \(sender)")
    }
    static func iconAlt(_ appName: String) -> Loc {
        Loc(ko: "\(appName) 아이콘", en: "\(appName) icon")
    }

    /// A date written the way each language writes it. Fixed patterns rather than
    /// `.dateTime`, because these end up in exported HTML that has to read the same
    /// wherever it's opened.
    private static func day(_ date: Date, _ language: AppLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateFormat = language == .korean ? "yyyy년 M월 d일" : "MMM d, yyyy"
        return formatter.string(from: date)
    }
}
