import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class ComposerModel: ObservableObject {

    @Published var draft = GiftDraft()
    @Published var query: String = ""
    @Published var storefront: String = "kr"
    @Published var artwork: NSImage?
    @Published var iconBase64: String?
    @Published var isLoading = false
    @Published var status: String?
    @Published var errorMessage: String?

    /// What the last pasted link decided on its own, shown so the user can see why the
    /// form filled itself in. Nil when nothing was inferred.
    @Published var autoFillNotice: String?

    /// Set once the user touches the kind picker, so a later lookup stops second-guessing
    /// them. An explicit `ctx=` in a freshly pasted link still wins — that's a new intent.
    @Published private(set) var kindChosenManually = false

    /// Multi-line input for batch mode: one gift per line, `CODE` or `CODE, 받는 사람`.
    @Published var batchInput: String = ""

    /// Where the card's pieces sit. Shared by the preview, the PNG export and the
    /// batch run, so what you arrange is what ships.
    @Published var layout: CardLayout = .load()
    @Published var selectedBlock: CardBlock?

    func resetLayout() {
        layout = .standard
        layout.save()
        selectedBlock = nil
        status = "카드 배치를 기본값으로 되돌렸습니다."
    }

    var link: String { draft.redeemURL?.absoluteString ?? "" }

    /// The wrapped link. Nil only while no app has been resolved — at which point
    /// there's no redeem link either, so nothing is shareable yet.
    var giftPageURL: URL? { GiftLinkBuilder.url(for: draft) }

    /// What goes in the message. The bare redeem URL is the fallback for a draft that
    /// somehow has a link but no page URL; in practice the two appear together.
    var shareLink: String { giftPageURL?.absoluteString ?? link }
    var shareStyle: GiftExporter.LinkStyle { giftPageURL == nil ? .redeem : .giftPage }

    // MARK: - Lookup

    /// The kind picker writes through here so a deliberate choice survives the next lookup.
    var kindSelection: Binding<GiftLinkKind> {
        Binding(
            get: { self.draft.kind },
            set: { newValue in
                guard newValue != self.draft.kind else { return }
                self.draft.kind = newValue
                self.kindChosenManually = true
                self.autoFillNotice = nil
            }
        )
    }

    func lookup() async {
        let input = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        status = nil
        autoFillNotice = nil
        defer { isLoading = false }

        let parsed = RedeemLinkBuilder.parse(input)
        let service = AppStoreLookupService(storefront: storefront)
        do {
            let app = try await service.lookup(input)
            draft.app = app
            apply(parsed, isFree: app.isFree)

            let data = await service.artworkData(for: app)
            iconBase64 = data?.base64EncodedString()
            artwork = data.flatMap(NSImage.init(data:))
            status = "\(app.name) 불러왔습니다."
        } catch {
            draft.app = nil
            artwork = nil
            iconBase64 = nil
            errorMessage = error.localizedDescription
        }
    }

    /// Pours the pasted link into the form: code and campaign params come straight from
    /// the URL, the delivery kind from `ctx=` if it's there and from the app's price if not.
    private func apply(_ parsed: RedeemLinkBuilder.ParsedLink?, isFree: Bool) {
        var filled: [String] = []

        if let code = parsed?.code, code != draft.trimmedCode {
            draft.code = code
            filled.append("코드")
        }
        if let pt = parsed?.providerToken, pt != draft.providerToken {
            draft.providerToken = pt
            filled.append("pt")
        }
        if let ct = parsed?.campaignCode, ct != draft.campaignCode {
            draft.campaignCode = ct
            filled.append("ct")
        }

        // An explicit ctx= is a fresh statement of intent and outranks an earlier manual pick.
        let explicit = parsed?.kind
        if explicit != nil || !kindChosenManually {
            let resolved = RedeemLinkBuilder.inferredKind(
                explicit: explicit,
                isFree: isFree,
                hasCode: !draft.trimmedCode.isEmpty
            )
            if resolved != draft.kind {
                draft.kind = resolved
                filled.insert(resolved.label, at: 0)
            }
            kindChosenManually = false
        }

        autoFillNotice = filled.isEmpty ? nil : "링크에서 " + filled.joined(separator: " · ") + " 자동 설정"
    }

    // MARK: - Single gift actions

    func copyLink() {
        guard !link.isEmpty else { return }
        GiftExporter.copy(text: link)
        status = "프로모션 링크를 복사했습니다 — App Store로 바로 갑니다."
    }

    func copyMessage() {
        guard !link.isEmpty else { return }
        GiftExporter.copy(
            text: GiftExporter.messageText(for: draft, link: shareLink, style: shareStyle)
        )
        status = "메시지를 복사했습니다 — 카드 이미지도 함께 보내세요."
    }

    /// One action: the message (carrying the gift-page link) plus the card image.
    func share(from view: NSView) {
        guard !link.isEmpty else { return }
        let text = GiftExporter.messageText(for: draft, link: shareLink, style: shareStyle)
        let image = cardPNG().flatMap(NSImage.init(data:))
        GiftExporter.share(text: text, image: image, from: view)
        status = "선물 링크와 카드 이미지를 함께 공유합니다."
    }

    func copyGiftLink() {
        guard let url = giftPageURL else { return }
        GiftExporter.copy(text: url.absoluteString)
        status = "선물 페이지 링크를 복사했습니다 — 카드부터 열립니다."
    }

    func openGiftLink() {
        guard let url = giftPageURL else { return }
        NSWorkspace.shared.open(url)
    }

    func copyCardImage() {
        guard let data = cardPNG() else { return }
        GiftExporter.copy(pngData: data)
        status = "카드 이미지를 복사했습니다."
    }

    func saveCardImage() {
        guard let data = cardPNG() else { return }
        let name = GiftExporter.fileStem(for: draft) + ".png"
        if let url = GiftExporter.save(data: data, suggestedName: name, type: .png) {
            status = "저장했습니다 — \(url.lastPathComponent)"
        }
    }

    func saveGiftPage() {
        guard !link.isEmpty else { return }
        let html = GiftPageTemplate.html(draft: draft, link: link, iconBase64: iconBase64)
        let name = GiftExporter.fileStem(for: draft) + ".html"
        if let url = GiftExporter.save(data: Data(html.utf8), suggestedName: name, type: .html) {
            status = "선물 페이지를 저장했습니다 — \(url.lastPathComponent)"
        }
    }

    func openLink() {
        guard let url = draft.redeemURL else { return }
        NSWorkspace.shared.open(url)
    }

    func cardPNG(scale: CGFloat = 3) -> Data? {
        GiftExporter.png(
            of: GiftCardView(draft: draft, artwork: artwork, layout: layout),
            size: GiftCardView.canvas,
            scale: scale
        )
    }

    func recordIssued(into ledger: GiftLedger) {
        guard let app = draft.app, !link.isEmpty else { return }
        ledger.add(
            GiftRecord(
                appName: app.name,
                appleID: app.id,
                kind: draft.kind,
                code: draft.trimmedCode,
                recipient: draft.recipient,
                link: shareLink,
                expiry: draft.expiry
            )
        )
        status = "보낸 기록에 추가했습니다."
    }

    // MARK: - Batch

    struct BatchEntry {
        let code: String
        let recipient: String
    }

    var batchEntries: [BatchEntry] {
        batchInput
            .split(separator: "\n")
            .map(String.init)
            .compactMap { line in
                let parts = line.split(separator: ",", maxSplits: 1).map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
                guard let first = parts.first, !first.isEmpty else { return nil }
                return BatchEntry(
                    code: first.uppercased(),
                    recipient: parts.count > 1 ? parts[1] : ""
                )
            }
    }

    /// Writes one PNG + one HTML page per code into a folder, plus a manifest CSV.
    func exportBatch(into ledger: GiftLedger) {
        guard draft.app != nil else { return }
        let entries = batchEntries
        guard !entries.isEmpty else {
            errorMessage = "코드를 한 줄에 하나씩 넣어주세요."
            return
        }
        guard let folder = GiftExporter.chooseFolder() else { return }

        var manifest = ["code,recipient,gift_link,redeem_link,png,html"]
        var written = 0

        for entry in entries {
            var copy = draft
            copy.code = entry.code
            if !entry.recipient.isEmpty { copy.recipient = entry.recipient }
            guard let url = copy.redeemURL else { continue }

            // The wrapped link, same as the single-gift path.
            let giftURL = GiftLinkBuilder.url(for: copy)
            let sendLink = giftURL?.absoluteString ?? url.absoluteString

            let stem = GiftExporter.fileStem(for: copy)
            let pngURL = folder.appendingPathComponent("\(stem).png")
            let htmlURL = folder.appendingPathComponent("\(stem).html")

            if let png = GiftExporter.png(
                of: GiftCardView(draft: copy, artwork: artwork, layout: layout),
                size: GiftCardView.canvas,
                scale: 3
            ) {
                try? png.write(to: pngURL, options: .atomic)
            }

            let html = GiftPageTemplate.html(
                draft: copy,
                link: url.absoluteString,
                iconBase64: iconBase64
            )
            try? Data(html.utf8).write(to: htmlURL, options: .atomic)

            manifest.append(
                "\(entry.code),\(entry.recipient),\(sendLink),\(url.absoluteString),"
                + "\(pngURL.lastPathComponent),\(htmlURL.lastPathComponent)"
            )

            if let app = copy.app {
                ledger.add(
                    GiftRecord(
                        appName: app.name,
                        appleID: app.id,
                        kind: copy.kind,
                        code: copy.trimmedCode,
                        recipient: copy.recipient,
                        link: sendLink,
                        expiry: copy.expiry
                    )
                )
            }
            written += 1
        }

        let manifestURL = folder.appendingPathComponent("gifts.csv")
        try? Data(manifest.joined(separator: "\n").utf8).write(to: manifestURL, options: .atomic)

        status = "\(written)장 내보냈습니다."
        GiftExporter.reveal(manifestURL)
    }
}
