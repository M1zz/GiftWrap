import SwiftUI
import UniformTypeIdentifiers

/// Drop in the file App Store Connect handed you, get that many cards and links back.
@MainActor
struct BatchView: View {
    @ObservedObject var model: ComposerModel
    @EnvironmentObject private var ledger: GiftLedger
    @ObservedObject private var loc = Localization.shared

    @State private var isDropTarget = false

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 14) {
                header

                TextEditor(text: $model.batchInput)
                    .font(.system(size: 12, design: .monospaced))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isDropTarget ? Color.accentColor : Color.secondary.opacity(0.25),
                                lineWidth: isDropTarget ? 2 : 1
                            )
                    )
                    // The file is the natural input here — five hundred codes is not
                    // something anyone should be pasting, let alone typing.
                    .onDrop(of: [.fileURL], isTargeted: $isDropTarget) { providers in
                        load(from: providers)
                    }

                HStack {
                    Text(loc.s(T.batchRecognised(model.batchEntries.count)))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(loc.s(T.batchImportCSV)) {
                        if let url = GiftExporter.chooseFile(types: [.commaSeparatedText, .plainText]) {
                            model.importCodes(from: url)
                        }
                    }
                    Button(loc.s(T.batchExport)) { model.exportBatch(into: ledger) }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.draft.app == nil || model.batchEntries.isEmpty)
                }

                if let status = model.status {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(minWidth: 380, idealWidth: 440)

            VStack(alignment: .leading, spacing: 12) {
                Text(loc.s(T.batchPreview))
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                // The same arrangement the export uses — this preview is a promise
                // about what lands in the folder.
                GiftCardPreview(draft: previewDraft, artwork: model.artwork, layout: model.layout)
                    .padding(20)

                Text(loc.s(T.batchPreviewNote))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .frame(minWidth: 480)
        }
    }

    /// Pulls the first dropped file's URL out and hands it to the model.
    private func load(from providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in model.importCodes(from: url) }
        }
        return true
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(loc.s(T.batchCodeList))
                .font(.headline)
            Text(loc.s(T.batchHint))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(loc.s(T.batchCSVHint))
                .font(.caption)
                .foregroundStyle(.secondary)
            if model.draft.app == nil {
                Label(loc.s(T.batchNeedsApp), systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    /// Shows the first entry so the operator sees exactly what ships.
    private var previewDraft: GiftDraft {
        var copy = model.draft
        if let first = model.batchEntries.first {
            copy.code = first.code
            if !first.recipient.isEmpty { copy.recipient = first.recipient }
        }
        return copy
    }
}
