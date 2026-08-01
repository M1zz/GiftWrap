import Foundation

/// Produces one standalone .html file per gift: no assets, no build step, no server.
/// Drop it on GitHub Pages / iCloud Drive / anywhere static and send the URL.
enum GiftPageTemplate {

    static func html(draft: GiftDraft, link: String, iconBase64: String?) -> String {
        let app = draft.app
        let theme = draft.theme
        let stops = theme.hexStops
        let blooms = theme.hexBlooms
        // The page is the recipient's, so every word on it comes from the card's language.
        let language = draft.cardLanguage
        let appName = escape(app?.name ?? "")
        let developer = escape(app?.developer ?? "")
        let recipient = escape(draft.recipient)
        let sender = escape(draft.sender)
        let message = escape(draft.message).replacingOccurrences(of: "\n", with: "<br>")
        let occasion = escape(
            draft.occasion.isEmpty ? C.defaultOccasion.text(language) : draft.occasion
        )
        let code = escape(draft.trimmedCode)
        let iconTag = iconBase64.map {
            let alt = escape(C.iconAlt(app?.name ?? "").text(language))
            return "<img class=\"icon\" src=\"data:image/png;base64,\($0)\" alt=\"\(alt)\">"
        } ?? "<div class=\"icon icon--placeholder\"></div>"

        let expiryLine: String
        if let expiry = draft.expiry, draft.kind.hasExpiry {
            expiryLine = "<p class=\"fine\">\(escape(C.usableUntil(expiry).text(language)))</p>"
        } else {
            expiryLine = ""
        }

        let codeBlock = code.isEmpty ? "" : """
                <div class="code-row">
                  <span class="code" id="code">\(code)</span>
                  <button class="copy" type="button" onclick="copyCode()">\(escape(C.copyCode.text(language)))</button>
                </div>
                <p class="fine">\(escape(C.manualRedeemShort.text(language)))</p>
        """

        let toLine = recipient.isEmpty
            ? ""
            : "<p class=\"to\">\(escape(C.to(draft.recipient).text(language)))</p>"
        let fromLine = sender.isEmpty
            ? ""
            : "<p class=\"from\">\(escape(C.from(draft.sender).text(language)))</p>"

        let shareTitle = sender.isEmpty
            ? occasion
            : escape(C.sharedTitle(draft.sender, draft.occasion.isEmpty
                ? C.defaultOccasion.text(language)
                : draft.occasion).text(language))

        return """
        <!DOCTYPE html>
        <html lang="\(language.htmlLang)">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(appName) — \(occasion)</title>
        <meta property="og:title" content="\(shareTitle)">
        <meta property="og:description" content="\(escape(C.pageDescription(app?.name ?? "").text(language)))">
        <style>
          :root {
            --stop-0: \(stops[0]);
            --stop-1: \(stops[1]);
            --stop-2: \(stops[2]);
            --bloom-0: \(blooms[0]);
            --bloom-1: \(blooms[1]);
            --page: #0B0B0F;
            --ink: #FFFFFF;
          }
          * { box-sizing: border-box; }
          body {
            margin: 0;
            min-height: 100vh;
            display: grid;
            place-items: center;
            padding: 32px 20px 56px;
            background: var(--page);
            font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Pretendard",
                         "Apple SD Gothic Neo", "Noto Sans KR", system-ui, sans-serif;
            color: var(--ink);
          }
          .stage { width: 100%; max-width: 560px; }
          .card {
            position: relative;
            overflow: hidden;
            border-radius: 32px;
            padding: 40px 36px 36px;
            background:
              radial-gradient(120% 100% at 12% 8%, var(--bloom-0) 0%, transparent 55%),
              radial-gradient(120% 120% at 88% 90%, var(--bloom-1) 0%, transparent 60%),
              linear-gradient(210deg, var(--stop-2) 0%, var(--stop-1) 48%, var(--stop-0) 100%);
            box-shadow: 0 30px 70px rgba(0,0,0,.45);
            animation: rise .7s cubic-bezier(.2,.8,.25,1) both;
          }
          .card::after {
            content: "";
            position: absolute; inset: 0;
            background: linear-gradient(115deg, rgba(255,255,255,.22) 0%, rgba(255,255,255,0) 42%);
            pointer-events: none;
          }
          .eyebrow {
            margin: 0 0 28px;
            font-size: 12px; font-weight: 700; letter-spacing: .22em;
            text-transform: uppercase; opacity: .8;
          }
          .head { display: flex; align-items: center; gap: 18px; }
          .icon {
            width: 84px; height: 84px; border-radius: 20px; display: block;
            box-shadow: 0 12px 28px rgba(0,0,0,.28);
          }
          .icon--placeholder { background: rgba(255,255,255,.25); }
          .name { margin: 0; font-size: 25px; font-weight: 700; letter-spacing: -.02em; }
          .dev  { margin: 4px 0 0; font-size: 14px; opacity: .78; }
          .message {
            margin: 28px 0 0; font-size: 17px; line-height: 1.6;
            white-space: normal; opacity: .96;
          }
          .to, .from { margin: 22px 0 0; font-size: 14px; opacity: .8; }
          .from { margin-top: 4px; }
          .actions { margin-top: 30px; }
          .cta {
            display: block; width: 100%; padding: 17px 20px;
            border: 0; border-radius: 999px; cursor: pointer;
            background: #fff; color: #111; text-align: center; text-decoration: none;
            font-size: 17px; font-weight: 600;
            transition: transform .16s ease, box-shadow .16s ease;
          }
          .cta:hover { transform: translateY(-2px); box-shadow: 0 12px 26px rgba(0,0,0,.28); }
          .cta:focus-visible { outline: 3px solid #fff; outline-offset: 3px; }
          .code-row {
            margin-top: 16px; display: flex; gap: 10px; align-items: stretch;
          }
          .code {
            flex: 1; padding: 13px 16px; border-radius: 14px;
            border: 1px dashed rgba(255,255,255,.55);
            font-family: ui-monospace, "SF Mono", Menlo, monospace;
            font-size: 15px; letter-spacing: .08em; text-align: center;
          }
          .copy {
            padding: 13px 16px; border-radius: 14px; cursor: pointer;
            border: 1px solid rgba(255,255,255,.5);
            background: rgba(255,255,255,.14); color: #fff; font-size: 14px; font-weight: 600;
          }
          .copy:hover { background: rgba(255,255,255,.24); }
          .fine { margin: 14px 2px 0; font-size: 12px; line-height: 1.5; opacity: .72; }
          @keyframes rise { from { opacity: 0; transform: translateY(18px); } to { opacity: 1; transform: none; } }
          @media (prefers-reduced-motion: reduce) {
            .card { animation: none; }
            .cta { transition: none; }
          }
          @media (max-width: 420px) {
            .card { padding: 30px 24px 28px; border-radius: 26px; }
            .icon { width: 68px; height: 68px; border-radius: 16px; }
            .name { font-size: 21px; }
          }
        </style>
        </head>
        <body>
          <main class="stage">
            <div class="card">
              <p class="eyebrow">\(occasion)</p>
              <div class="head">
                \(iconTag)
                <div>
                  <h1 class="name">\(appName)</h1>
                  <p class="dev">\(developer)</p>
                </div>
              </div>
              <p class="message">\(message)</p>
              \(toLine)
              \(fromLine)
              <div class="actions">
                <a class="cta" href="\(escape(link))">\(escape(C.openInStore.text(language)))</a>
        \(codeBlock)
              </div>
              \(expiryLine)
            </div>
          </main>
          <script>
            function copyCode() {
              const el = document.getElementById('code');
              if (!el) return;
              navigator.clipboard.writeText(el.textContent.trim()).then(() => {
                const button = document.querySelector('.copy');
                const original = button.textContent;
                button.textContent = '\(escape(C.copiedCode.text(language)))';
                setTimeout(() => { button.textContent = original; }, 1600);
              });
            }
          </script>
        </body>
        </html>
        """
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
