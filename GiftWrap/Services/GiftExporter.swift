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

    static func chooseFolder(prompt: String = T.chooseFolder.text) -> URL? {
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

    /// The text you paste into a messenger, iMessage, or an email.
    /// Hands the message and the card to the system share sheet as one action, so the
    /// wrapping and the working link travel together instead of being pasted twice.
    static func share(text: String, image: NSImage?, from view: NSView) {
        var items: [Any] = [text]
        if let image { items.append(image) }
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    /// How the link in the message behaves, which decides how much the message may say.
    enum LinkStyle {
        /// A bare redeem URL. The message has to carry the fallback itself.
        case redeem
        /// The gift page, which wraps the reveal. Naming the app or printing the code
        /// here would spoil what the page is about to unwrap — and the page already
        /// carries the code and the manual instructions, so nothing is lost.
        case giftPage
    }

    /// Written in the card's language, not the interface's — this is the recipient's copy.
    static func messageText(for draft: GiftDraft, link: String, style: LinkStyle = .redeem) -> String {
        let language = draft.cardLanguage
        var lines: [String] = []

        if !draft.recipient.isEmpty {
            lines.append(C.toHonorific(draft.recipient).text(language))
        }

        if style == .giftPage {
            lines.append("")
            lines.append(C.giftArrived.text(language))
            lines.append(link)
        } else {
            if !draft.message.isEmpty { lines.append(draft.message) }
            if let app = draft.app {
                lines.append("")
                lines.append("🎁 \(app.name)")
            }
            lines.append(link)

            if draft.kind.requiresCode && !draft.trimmedCode.isEmpty {
                lines.append(C.codeLine(draft.trimmedCode).text(language))
                lines.append(C.manualRedeem.text(language))
            }
        }

        if let expiry = draft.expiry, draft.kind.hasExpiry {
            lines.append(C.usableUntil(expiry).text(language))
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
