# GiftWrap — App Store gift card composer for macOS

Turns an App Store link plus a promo/offer code into something that looks like a gift:
a rendered card image, a shareable message, and a standalone HTML gift page.

Built for the workflow where App Store Connect gives you codes but no wrapping paper.

---

## What it does

| Step | In the app |
|---|---|
| Resolve the app | Paste an App Store URL or numeric ID → iTunes Lookup API returns name, developer, price, icon |
| Pick the delivery | Direct link · app promo code (`ctx=apps`) · offer code (`ctx=offercodes`) |
| Compose | Recipient, sender, occasion, message, theme, optional code chip and QR |
| Export | PNG (3000×1890) · message text · redeem link · self-contained HTML page |
| Track | Local ledger of which code went to whom, duplicate-code warning, CSV export |
| Batch | Paste 100 codes → 100 PNGs + 100 HTML pages + `gifts.csv` manifest in one folder |

The redeem URL follows Apple's format:

```
https://apps.apple.com/redeem?ctx=offercodes&id={APPLE_ID}&code={CODE}
https://apps.apple.com/redeem?ctx=apps&id={APPLE_ID}&code={CODE}
```

Optional `pt` / `ct` campaign parameters are appended when filled in.

---

## Setup

Requires **macOS 14+** and Xcode 15+.

```bash
open GiftWrap.xcodeproj
```

Press ⌘R. The scheme, sandbox entitlements, and asset catalog are already wired up.

Two things to change before you ship anything:

- **Bundle identifier** — currently `com.devkoan.GiftWrap`, in target → Signing & Capabilities
- **Team** — set your own; local runs work fine with "Sign to Run Locally"

Entitlements in use (`GiftWrap/GiftWrap.entitlements`):

| Entitlement | Why |
|---|---|
| `com.apple.security.app-sandbox` | Standard sandbox |
| `com.apple.security.network.client` | iTunes Lookup API + icon download |
| `com.apple.security.files.user-selected.read-write` | Save panels for PNG / HTML / CSV |

No API key, no App Store Connect credentials — the lookup endpoint is public.

Command-line build, if you'd rather:

```bash
xcodebuild -project GiftWrap.xcodeproj -scheme GiftWrap -configuration Debug build
```

The app icon slots in `Assets.xcassets` are empty placeholders — drop a 1024pt icon in
whenever you want it to stop looking like a generic app in the Dock.

---

## File map

```
tools/
├── giftsheet.html             CSV → A4 인쇄 시트 + 전송용 문구 (브라우저만 있으면 동작)
├── qr.js                      의존성 없는 QR 인코더 — Vision으로 500개 전량 검증
└── README.md
GiftWrap.xcodeproj/            Ready to open — shared scheme included
GiftWrap/
├── GiftWrapApp.swift              App entry, ledger injection
├── GiftWrap.entitlements          Sandbox: network client + user-selected files
├── Assets.xcassets/               AppIcon + accent color placeholders
├── Models/
│   ├── AppStoreApp.swift          Product metadata + lookup decoding
│   ├── GiftCard.swift             GiftDraft, GiftLinkKind, GiftRecord
│   └── GiftTheme.swift            Five palettes + hex bridge for HTML
├── Services/
│   ├── AppStoreLookupService.swift  iTunes Lookup + artwork fetch
│   ├── RedeemLinkBuilder.swift      Redeem URLs, campaign params, ID parsing
│   ├── GiftExporter.swift           ImageRenderer, pasteboard, save panels, message text
│   ├── GiftLedger.swift             JSON persistence in Application Support
│   └── QRCodeRenderer.swift         CoreImage QR
├── Resources/
│   └── GiftPageTemplate.swift     Standalone HTML gift page
└── Views/
    ├── ContentView.swift          Composer form + live preview + action bar
    ├── ComposerModel.swift        State, lookup, exports, batch
    ├── GiftCardView.swift         The card, on a fixed 1000×630 canvas
    ├── BatchView.swift            Many codes at once
    └── LedgerView.swift           Issued-gift table
```

The card preview and the exported PNG are the same view at different scales, so what
you see is exactly what ships.

---

## Sending flow

1. **Free app + IAP** → offer code. Generate one-time-use codes in App Store Connect
   (Subscription/IAP → Offer Codes), paste them into the batch tab.
2. **Paid app** → promo code. App Store Connect → your app → Promo Codes, up to 100 per
   version per platform, valid four weeks.
3. Export the HTML page, drop it on GitHub Pages, send the URL. The recipient sees the
   card, taps **App Store에서 받기**, and the redemption sheet opens with the code prefilled.
4. Fallback text is already in the page and the copied message: App Store → profile →
   기프트 카드 또는 코드 사용.

---

## Two things to keep in mind

- **Promo codes are non-commercial.** Apple's terms don't allow selling them, so this is
  for giveaways, reviewers, workshops, and events — not a paid gifting product. Paid
  gifting only exists through App Store's own "앱 선물하기", which covers paid apps only.
- **No Apple artwork.** The palettes and layout here are drawn from scratch. Don't add the
  Apple logo or App Store badge artwork to the card unless you follow Apple's marketing
  guidelines for them; the plain text "App Store에서 받기" used here stays on the safe side.
