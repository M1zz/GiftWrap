# GiftWrap — App Store gift card composer for macOS

Turns an App Store link plus a promo/offer code into something that looks like a gift:
a rendered card image, a shareable message, and a standalone HTML gift page.

Built for the workflow where App Store Connect gives you codes but no wrapping paper.

---

## What it does

| Step | In the app |
|---|---|
| Resolve the app | Paste an App Store URL or numeric ID → the delivery kind, code and campaign params come out of the link too |
| Pick the delivery | Direct link · app promo code (`ctx=apps`) · offer code (`ctx=offercodes`) — preselected from what you pasted |
| Compose | Recipient, sender, occasion, message, theme, optional code chip and QR |
| Arrange | Drag any piece of the card where you want it; resize the icon and the QR |
| Export | PNG (3000×1890) · message text · redeem link · self-contained HTML page |
| Track | Local ledger of which code went to whom, duplicate-code warning, CSV export |
| Batch | Paste 100 codes → 100 PNGs + 100 HTML pages + `gifts.csv` manifest in one folder |

## Arranging the card

The preview is the editor. Click a piece to select it, then:

- **Drag** to move. It snaps to the padding lines, the card centre, and the edges of the
  other pieces, with guides showing what it caught. Hold **Option** to move freely.
- **Arrow keys** nudge by 1pt, **Shift + arrows** by 10.
- **Everything resizes** — drag the grip on the corner of the selection, or press
  **+** / **−** (5% a step, 20% with Shift). The size shows as a percentage on the
  selection label. Artwork scales its frame; text scales its font, along with the
  spacing and wrap width that hang off it, so a resized line grows as a piece instead
  of just changing point size.
- **Esc** deselects, **배치 초기화** returns everything to the composed default.

Resizing grows a piece down and to the right from where it sits, so after a big change
you'll usually want to nudge its neighbours. Nothing can be pushed off the card — a
piece that would leave the canvas is pulled back in.

The arrangement is saved between launches and is used by the PNG export and the batch
run, so what you arrange is what ships. The standalone HTML gift page has its own fixed
layout and is not affected.

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

The app icon is generated, not hand-drawn — a wrapped present in the `sunrise` palette the
cards use, so the icon and its output are visibly the same product:

```bash
swift tools/appicon.swift
```

That fills `Assets.xcassets/AppIcon.appiconset` with `icon_16` … `icon_1024`. Pass a
directory to write somewhere else. Edit the constants at the top of the script to
re-colour it — the ribbon geometry is all in one 1024pt design space.

---

## File map

```
web/
└── gift.html                  받는 사람이 여는 선물 페이지 — 포장을 풀고 받기 버튼을 냄
                               (정적 파일 하나로 모든 선물을 처리, 값은 URL 프래그먼트로)
tools/
├── giftsheet.html             CSV → A4 인쇄 시트 + 전송용 문구 (브라우저만 있으면 동작)
├── qr.js                      의존성 없는 QR 인코더 — Vision으로 500개 전량 검증
├── appicon.swift              선물 상자 앱 아이콘 생성기 (CoreGraphics, 16~1024px)
└── README.md
GiftWrap.xcodeproj/            Ready to open — shared scheme included
GiftWrap/
├── GiftWrapApp.swift              App entry, ledger injection
├── GiftWrap.entitlements          Sandbox: network client + user-selected files
├── Assets.xcassets/               AppIcon + accent color placeholders
├── Models/
│   ├── AppStoreApp.swift          Product metadata + lookup decoding
│   ├── GiftCard.swift             GiftDraft, GiftLinkKind, GiftRecord,
│   │                              CardLayout — block placement, snapping, persistence
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
    ├── GiftCardView.swift         The card on a fixed 1000×630 canvas, every piece
    │                              placed from CardLayout + EditableCardPreview (the editor)
    ├── BatchView.swift            Many codes at once
    └── LedgerView.swift           Issued-gift table
```

The card preview and the exported PNG are the same view at different scales, so what
you see is exactly what ships.

---

## The gift page

`web/gift.html` is what the recipient opens. It arrives closed — a wrapped tile with a
ribbon and their name on it — and only after they tap does it unwrap into the card, the
message, and the **App Store에서 받기** button.

It's already published from this repo's `gh-pages` branch:

```
https://m1zz.github.io/GiftWrap/gift.html
```

There is nothing to configure. The address is a constant (`GiftLinkBuilder.pageURL`), not
a setting — the app would only be asking you to type back something it already knows, and
a typo there would break links for the people you send them to. **공유** hands the share
sheet the message (carrying the wrapped link) and the card image in one action; **더보기 →
선물 링크 복사** gives you just the URL.

Hosting your own copy is a one-line change to that constant.

The image is the wrapping paper, the link is the thing that works.

```
https://your.host/gift.html#eyJ2IjoxLCJuIjoi7Iuk7IiYIDEwMCIsIm0iOi...
```

**The page draws the card you composed**, not one of its own. The link carries the block
arrangement — each piece's position and size — plus the QR and code-chip toggles, and the
page lays the card out on the same 1000 × 630 grid scaled to the screen. Move the QR in
the composer and it moves on the phone. The QR itself is drawn in-page by `tools/qr.js`,
inlined so the file stays standalone.

It is a reproduction, not the exported PNG: fonts and shadows render as the browser draws
them, so it is very close but not pixel-identical. The app composes in SF Rounded and SF
Mono, which no browser has, so the same words come out wider on the web — enough that the
code chip used to slide under the QR. The link therefore also carries the **footprint each
block occupied** in the preview, and the page scales each piece to that box before
clamping anything that would still leave the card. Arrangement in, arrangement out.

If you host a rendered card somewhere, put its URL in the payload's `img` and the page
shows that instead. There's a reason it isn't the default — see below.

Three things worth knowing about the design:

- **Everything rides in the fragment (`#`), not the query string.** A fragment is never
  sent to the server, so the redeem code and the recipient's name stay out of access
  logs, referrers, and any proxy in between. The page stays a plain static file: one
  upload serves every gift.
- **The message stops teasing.** When a gift-page link is used, the copied message drops
  the app name and the code — printing them in the chat would spoil the thing the page
  is about to unwrap. The code and the manual App Store instructions live on the page,
  so nothing is lost if the button fails.
- **There's always an escape.** "그냥 바로 받기" skips the animation, and
  `prefers-reduced-motion` skips it automatically. Nobody has to unwrap to get their code.
- **The card image is never uploaded.** A PNG is far too big for a link, and hosting one
  per gift would put the recipient's name and message on a public URL — exactly what the
  fragment exists to prevent. The card travels as coordinates instead. The share sheet
  still sends the real PNG alongside the link, so the recipient sees it in the chat.

When the recipient comes back from the App Store, the page notices and offers **앱 열기**
along with the sender's name — the one place the giver survives the handoff to Apple.

The page has no build step and no dependencies. Open it with no fragment and it renders a
demo gift, which is also how you preview a design change.

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
