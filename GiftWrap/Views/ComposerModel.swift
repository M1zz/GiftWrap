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

    /// Multi-line input for batch mode: one gift per line, `CODE` or `CODE, recipient`.
    @Published var batchInput: String = ""

    /// Where the card's pieces sit, for the style currently being composed in. Shared
    /// by the preview, the PNG export and the batch run, so what you arrange is what
    /// ships.
    @Published var layout: CardLayout = .load(.current)
    @Published var selectedBlock: CardBlock?

    /// The style picker writes through here so that each design keeps its own
    /// arrangement: what's on screen is saved before the switch, and the incoming
    /// style's own saved arrangement — or its defaults — comes back.
    var styleSelection: Binding<CardStyle> {
        Binding(
            get: { self.draft.style },
            set: { newValue in
                guard newValue != self.draft.style else { return }
                self.layout.save()
                self.draft.style = newValue
                self.layout = .load(newValue)
                self.selectedBlock = nil
                CardStyle.persist(newValue)
            }
        )
    }

    func resetLayout() {
        layout = .defaults(for: draft.style)
        layout.save()
        selectedBlock = nil
        status = T.layoutReset.text
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
            status = T.loaded(app.name).text
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
            filled.append(T.codeField.text)
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

        autoFillNotice = filled.isEmpty
            ? nil
            : T.autoFilled(filled.joined(separator: " · ")).text
    }

    // MARK: - Single gift actions

    func copyLink() {
        guard !link.isEmpty else { return }
        GiftExporter.copy(text: link)
        status = T.copiedRedeemLink.text
    }

    func copyMessage() {
        guard !link.isEmpty else { return }
        GiftExporter.copy(
            text: GiftExporter.messageText(for: draft, link: shareLink, style: shareStyle)
        )
        status = T.copiedMessage.text
    }

    /// One action: the message (carrying the gift-page link) plus the card image.
    func share(from view: NSView) {
        guard !link.isEmpty else { return }
        let text = GiftExporter.messageText(for: draft, link: shareLink, style: shareStyle)
        let image = cardPNG().flatMap(NSImage.init(data:))
        GiftExporter.share(text: text, image: image, from: view)
        status = T.sharing.text
    }

    func copyGiftLink() {
        guard let url = giftPageURL else { return }
        GiftExporter.copy(text: url.absoluteString)
        status = T.copiedGiftLink.text
    }

    func openGiftLink() {
        guard let url = giftPageURL else { return }
        NSWorkspace.shared.open(url)
    }

    func copyCardImage() {
        guard let data = cardPNG() else { return }
        GiftExporter.copy(pngData: data)
        status = T.copiedImage.text
    }

    func saveCardImage() {
        guard let data = cardPNG() else { return }
        let name = GiftExporter.fileStem(for: draft) + ".png"
        if let url = GiftExporter.save(data: data, suggestedName: name, type: .png) {
            status = T.savedFile(url.lastPathComponent).text
        }
    }

    func saveGiftPage() {
        guard !link.isEmpty else { return }
        let html = GiftPageTemplate.html(draft: draft, link: link, iconBase64: iconBase64)
        let name = GiftExporter.fileStem(for: draft) + ".html"
        if let url = GiftExporter.save(data: Data(html.utf8), suggestedName: name, type: .html) {
            status = T.savedGiftPage(url.lastPathComponent).text
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
        status = T.recordedInLedger.text
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
            errorMessage = T.batchNeedsCodes.text
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

        status = T.exportedCount(written).text
        GiftExporter.reveal(manifestURL)
    }
}
