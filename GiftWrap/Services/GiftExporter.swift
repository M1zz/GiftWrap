import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
enum GiftExporter {

    // MARK: - Rendering

    /// Renders the card at print resolution (3000 × 1890 by default).
    static func png<V: View>(of view: V, size: CGSize, scale: CGFloat = 3) -> Data? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = scale
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    // MARK: - Clipboard

    static func copy(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    static func copy(pngData: Data) {
        guard let image = NSImage(data: pngData) else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    // MARK: - Files

    @discardableResult
    static func save(data: Data, suggestedName: String, type: UTType) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        try? data.write(to: url, options: .atomic)
        return url
    }

    static func chooseFolder(prompt: String = "이 폴더에 저장") -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = prompt
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Message text

    /// The text you paste into KakaoTalk, iMessage, or an email.
    static func messageText(for draft: GiftDraft, link: String) -> String {
        var lines: [String] = []

        if !draft.recipient.isEmpty { lines.append("\(draft.recipient)님께") }
        if !draft.message.isEmpty { lines.append(draft.message) }

        if let app = draft.app {
            lines.append("")
            lines.append("🎁 \(app.name)")
        }
        lines.append(link)

        if draft.kind.requiresCode && !draft.trimmedCode.isEmpty {
            lines.append("코드: \(draft.trimmedCode)")
            lines.append("링크가 열리지 않으면 App Store → 프로필 → ‘기프트 카드 또는 코드 사용’에 입력하세요.")
        }

        if let expiry = draft.expiry, draft.kind.hasExpiry {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "yyyy년 M월 d일"
            lines.append("\(formatter.string(from: expiry))까지 사용 가능합니다.")
        }

        if !draft.sender.isEmpty {
            lines.append("")
            lines.append("— \(draft.sender)")
        }

        return lines.joined(separator: "\n")
    }

    /// Filesystem-safe base name for a gift's exported files.
    static func fileStem(for draft: GiftDraft) -> String {
        let app = draft.app?.name ?? "gift"
        let who = draft.recipient.isEmpty ? draft.trimmedCode : draft.recipient
        let raw = who.isEmpty ? app : "\(app)-\(who)"
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        return String(cleaned).replacingOccurrences(of: "--", with: "-").lowercased()
    }
}
