# GiftWrap — App Store gift card composer

Turns an App Store link plus a promo/offer code into something that looks like a gift:
a rendered card image, a shareable message, and a link the recipient can unwrap.

Built for the workflow where App Store Connect gives you codes but no wrapping paper.

---

## Two pages, and they are not the same page

This trips people up, so it comes first. There is a page **you** use to make gifts and a
page **they** open to receive one. They are different files, and only one of them is
meant to be handed out.

| | You (the sender) | Them (the recipient) |
|---|---|---|
| **Where** | [**studio.html**](https://m1zz.github.io/GiftWrap/studio.html) | [**gift.html**](https://m1zz.github.io/GiftWrap/gift.html) |
| **What it is** | The composer — the client you work in | The gift itself, wrapped |
| **You open it** | Yes, this is your tool | Only to preview |
| **You send it** | Never | Yes — this is the link you send |
| **Holds a gift?** | No. Your drafts and ledger stay in your browser | Yes — the whole gift rides in the URL |

```
   ┌─────────────────────────────┐
   │  studio.html                │   ← 당신이 여는 곳. 카드를 만든다.
   │  (or the macOS app)         │     보내지 않는다.
   └──────────────┬──────────────┘
                  │  "선물 페이지 링크 복사" / 앱의 "공유"
                  ▼
   gift.html?d=eyJ2IjoxLCJuIjoi7Iuk...     ← 이 링크만 보낸다
                  │
                  ▼
   ┌─────────────────────────────┐
   │  gift.html                  │   ← 받는 사람이 여는 곳.
   │  포장을 풀고 → App Store    │     선물이 URL 안에 들어 있다.
   └─────────────────────────────┘
```

`studio.html` never appears in a link you send. `gift.html` is never useful on its own —
open it bare and it just shows a demo gift, which is how you preview a design change.

**One page, every gift.** `gift.html` is a single static file that is uploaded once. It
holds no gifts and no database; each gift arrives inside its own URL. Sending a hundred
gifts means a hundred links to the same file, not a hundred uploads.

---

## Getting started in a browser (no Xcode)

The fastest path — nothing to install, nothing to build:

1. Open **<https://m1zz.github.io/GiftWrap/studio.html>**
2. Paste your App Store link or numeric ID into **App Store 링크 또는 ID**. The app name,
   icon, and the delivery kind are read out of the link.
3. Under **전달 방식**, confirm the kind — **다운로드 링크** (no code, just the store page)
   · **앱 프로모션 코드** · **인앱 오퍼 코드**. Paste the code, if there is one.
4. Fill in **받는 사람** / **보내는 사람** / **메시지**, pick a design, and drag the pieces
   of the card where you want them.
5. **받는 화면 미리보기** opens the recipient's page so you can check it before sending.
6. Press **선물 페이지 링크 복사**. That is the `gift.html` URL — **this is what you send.**
   **문구 복사** gives you the message to send with it, and **PNG 저장** the card image
   to attach.
7. **보낸 기록에 추가** records which code went to whom, so the next gift can warn you if
   you reuse it.

The other copy button, **프로모션 링크만 복사**, gives the bare `apps.apple.com/redeem`
URL with no wrapping — useful when you just want the code to work, with no gift page in
front of it.

The Studio has the same three tabs as the macOS app:

| Tab | What it's for |
|---|---|
| **카드 만들기** | One gift at a time — compose, arrange, copy the link |
| **여러 장 만들기** | Drop App Store Connect's `OfferCodeOneTimeUseCodes….csv` straight in, or type one code per line (`코드, 이름` also works). Duplicates and blank lines are dropped and counted. Then **CSV 내보내기** for the links, **PNG 전부 저장** for the cards. The design comes from the 카드 만들기 tab — only the code and the recipient change per row |
| **보낸 기록** | Which code went to whom, per-row **링크 복사**, duplicate-code warning, **CSV 내보내기** |

Your drafts, card arrangement, and the ledger live in that browser's `localStorage`
(`giftwrap.layout.*`, `giftwrap.ledger`). Nothing is uploaded, and nothing syncs to
another machine — **기록 지우기** wipes it. The macOS app keeps its own ledger separately
in Application Support; the two do not share.

---

## What it does

The macOS app and the Studio do the same job; use whichever you prefer. The app renders
the PNG through the same view it previews, so exports are pixel-exact; the Studio needs
no Xcode.

| Step | In the app or the Studio |
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
web/                           ← 그대로 gh-pages 로 배포되어 m1zz.github.io/GiftWrap/ 이 됨
├── gift.html                  받는 사람이 여는 선물 페이지 — 포장을 풀고 받기 버튼을 냄
│                              (정적 파일 하나로 모든 선물을 처리, 선물은 URL 안에)
├── studio.html                보내는 사람이 쓰는 브라우저 composer — 카드/여러 장/보낸 기록
│                              (macOS 앱과 같은 일, 설치 없이. 저장은 localStorage)
└── qr.js                      QR 인코더 — studio.html 이 옆 파일로 불러 씀
                               (gift.html 은 같은 코드를 인라인으로 품어 단일 파일 유지)
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

It's already published, alongside the Studio:

```
https://m1zz.github.io/GiftWrap/gift.html      ← 받는 사람
https://m1zz.github.io/GiftWrap/studio.html    ← 보내는 사람
```

There is nothing to configure. The address is a constant (`GiftLinkBuilder.pageURL`), not
a setting — the app would only be asking you to type back something it already knows, and
a typo there would break links for the people you send them to. **공유** hands the share
sheet the message (carrying the wrapped link) and the card image in one action; **더보기 →
선물 링크 복사** gives you just the URL.

Hosting your own copy is a one-line change to that constant.

The image is the wrapping paper, the link is the thing that works.

```
https://your.host/gift.html?d=eyJ2IjoxLCJuIjoi7Iuk7IiYIDEwMCIsIm0iOi...
```

**The page draws the card you composed**, not one of its own. The link carries the block
arrangement — each piece's position and size — plus the QR and code-chip toggles, and the
page lays the card out on the same 1000 × 630 grid scaled to the screen. Move the QR in
the composer and it moves on the phone. The QR itself is drawn in-page by the `qr.js`
encoder, inlined into `gift.html` so that file stays standalone — one file, no requests.

It is a reproduction, not the exported PNG: fonts and shadows render as the browser draws
them, so it is very close but not pixel-identical. The app composes in SF Rounded and SF
Mono, which no browser has, so the same words come out wider on the web — enough that the
code chip used to slide under the QR. The link therefore also carries the **footprint each
block occupied** in the preview, and the page scales each piece to that box before
clamping anything that would still leave the card. Arrangement in, arrangement out.

If you host a rendered card somewhere, put its URL in the payload's `img` and the page
shows that instead. There's a reason it isn't the default — see below.

Four things worth knowing about the design:

- **Everything rides in the URL (`?d=`), so the page stays a plain static file** — one
  upload serves every gift, and there is no server or database holding anyone's code.

  It used to ride in the fragment (`#`), which browsers never send to the server, keeping
  the code and the recipient's name out of access logs and referrers. Messengers broke
  that: some linkify only up to the `#`, and the fragment *was* the gift, so the
  recipient tapped a link that had lost everything in it. A gift that doesn't arrive
  beats a gift that arrives privately, so it moved to the query string. Fragments are
  still read, so links already sent keep working.

  What that costs, and what it doesn't: whoever hosts `gift.html` can now see the gift in
  their request logs — on GitHub Pages, that's GitHub. It does not go further. The page
  sends `Referrer-Policy: no-referrer`, so the URL is not handed to Apple or to the icon
  CDN on the way out, and `noindex` keeps it out of search. Treat a gift link like the
  code inside it: it is unguessable, not secret. **If that trade isn't right for you,
  host `gift.html` yourself** — it's one static file, and then the only log is yours.
- **The message stops teasing.** When a gift-page link is used, the copied message drops
  the app name and the code — printing them in the chat would spoil the thing the page
  is about to unwrap. The code and the manual App Store instructions live on the page,
  so nothing is lost if the button fails.
- **There's always an escape.** "그냥 바로 받기" skips the animation, and
  `prefers-reduced-motion` skips it automatically. Nobody has to unwrap to get their code.
- **The card image is never uploaded.** A PNG is far too big for a link, and hosting one
  per gift would leave the recipient's name and message sitting on a public URL after the
  gift is over. The card travels as coordinates instead. The share sheet still sends the
  real PNG alongside the link, so the recipient sees it in the chat.

When the recipient comes back from the App Store, the page notices and offers **앱 열기**
along with the sender's name — the one place the giver survives the handoff to Apple.

The page has no build step and no dependencies. Open it with no payload and it renders a
demo gift, which is also how you preview a design change.

---

## Publishing

`web/` on `main` is the only copy to edit. Pushing it publishes it:

```
web/ on main  ──push──▶  .github/workflows/pages.yml  ──▶  gh-pages  ──▶  m1zz.github.io/GiftWrap/
```

`gh-pages` is a build output. It shares no history with `main` and **nothing should be
committed to it by hand** — the next publish overwrites it to match `web/` exactly,
deletions included. It used to be maintained by hand, which meant every web change had
to be committed twice and the two copies could quietly drift.

To publish without touching `web/`, run the **Publish web/ to gh-pages** workflow from
the Actions tab. To check what's actually live:

```bash
git fetch origin gh-pages
git diff origin/gh-pages main:web --stat    # empty = the site matches main
```

Hosting it yourself is just uploading `web/` somewhere — three static files, no build.
Point the macOS app at your copy by changing `GiftLinkBuilder.pageURL`, and the Studio by
changing its `GIFT_PAGE` constant.

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
