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

    /// Multi-line input for batch mode: one gift per line, `CODE` or `CODE, 받는 사람`.
    @Published var batchInput: String = ""

    var link: String { draft.redeemURL?.absoluteString ?? "" }

    // MARK: - Lookup

    func lookup() async {
        let input = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        status = nil
        defer { isLoading = false }

        let service = AppStoreLookupService(storefront: storefront)
        do {
            let app = try await service.lookup(input)
            draft.app = app
            // A free app can't carry an app promo code, so nudge toward the right kind.
            if app.isFree, draft.kind == .appPromoCode { draft.kind = .offerCode }
            if !app.isFree, draft.kind == .offerCode { draft.kind = .appPromoCode }

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

    // MARK: - Single gift actions

    func copyLink() {
        guard !link.isEmpty else { return }
        GiftExporter.copy(text: link)
        status = "링크를 복사했습니다."
    }

    func copyMessage() {
        guard !link.isEmpty else { return }
        GiftExporter.copy(text: GiftExporter.messageText(for: draft, link: link))
        status = "메시지를 복사했습니다."
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
            of: GiftCardView(draft: draft, artwork: artwork),
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
                link: link,
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

        var manifest = ["code,recipient,link,png,html"]
        var written = 0

        for entry in entries {
            var copy = draft
            copy.code = entry.code
            if !entry.recipient.isEmpty { copy.recipient = entry.recipient }
            guard let url = copy.redeemURL else { continue }

            let stem = GiftExporter.fileStem(for: copy)
            let pngURL = folder.appendingPathComponent("\(stem).png")
            let htmlURL = folder.appendingPathComponent("\(stem).html")

            if let png = GiftExporter.png(
                of: GiftCardView(draft: copy, artwork: artwork),
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

            manifest.append("\(entry.code),\(entry.recipient),\(url.absoluteString),\(pngURL.lastPathComponent),\(htmlURL.lastPathComponent)")

            if let app = copy.app {
                ledger.add(
                    GiftRecord(
                        appName: app.name,
                        appleID: app.id,
                        kind: copy.kind,
                        code: copy.trimmedCode,
                        recipient: copy.recipient,
                        link: url.absoluteString,
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
