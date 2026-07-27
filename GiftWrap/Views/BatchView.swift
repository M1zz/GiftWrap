import SwiftUI

/// Paste the 100 codes App Store Connect handed you, get 100 cards and 100 links back.
@MainActor
struct BatchView: View {
    @ObservedObject var model: ComposerModel
    @EnvironmentObject private var ledger: GiftLedger

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 14) {
                header

                TextEditor(text: $model.batchInput)
                    .font(.system(size: 12, design: .monospaced))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.25))
                    )

                HStack {
                    Text("\(model.batchEntries.count)개 인식됨")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("폴더로 내보내기") { model.exportBatch(into: ledger) }
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
                Text("미리보기")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                GiftCardPreview(draft: previewDraft, artwork: model.artwork)
                    .padding(20)

                Text("카드 색상·문구·메시지는 ‘카드 만들기’ 탭 설정을 그대로 씁니다. 코드와 받는 사람만 줄마다 달라집니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .frame(minWidth: 480)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("코드 목록")
                .font(.headline)
            Text("한 줄에 하나씩. 받는 사람을 함께 적으려면 `코드, 이름` 형식으로 쓰세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if model.draft.app == nil {
                Label("먼저 ‘카드 만들기’ 탭에서 앱을 불러오세요.", systemImage: "info.circle")
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
