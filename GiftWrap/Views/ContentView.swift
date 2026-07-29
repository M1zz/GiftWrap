import SwiftUI

@MainActor
struct ContentView: View {
    @StateObject private var model = ComposerModel()

    var body: some View {
        TabView {
            ComposerView(model: model)
                .tabItem { Label("카드 만들기", systemImage: "gift") }

            BatchView(model: model)
                .tabItem { Label("여러 장 만들기", systemImage: "square.stack.3d.up") }

            LedgerView()
                .tabItem { Label("보낸 기록", systemImage: "list.bullet.rectangle") }
        }
        .padding(12)
    }
}

// MARK: - Composer

@MainActor
struct ComposerView: View {
    @ObservedObject var model: ComposerModel
    @EnvironmentObject private var ledger: GiftLedger
    @State private var hasExpiry = false

    var body: some View {
        HSplitView {
            editor
                .frame(minWidth: 380, idealWidth: 420, maxWidth: 520)

            VStack(spacing: 0) {
                EditableCardPreview(
                    draft: model.draft,
                    artwork: model.artwork,
                    layout: $model.layout,
                    selection: $model.selectedBlock,
                    onMeasure: { model.blockSizes = $0 }
                )
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(previewBackdrop)

                layoutBar
                actionBar
            }
            .frame(minWidth: 520)
        }
    }

    // MARK: Editor

    private var editor: some View {
        Form {
            Section("앱") {
                HStack {
                    TextField("App Store 링크 또는 ID", text: $model.query)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await model.lookup() } }
                    Button("불러오기") { Task { await model.lookup() } }
                        .disabled(model.query.isEmpty || model.isLoading)
                }
                Picker("스토어프론트", selection: $model.storefront) {
                    Text("한국 (kr)").tag("kr")
                    Text("미국 (us)").tag("us")
                    Text("일본 (jp)").tag("jp")
                    Text("영국 (gb)").tag("gb")
                }
                if model.isLoading {
                    ProgressView().controlSize(.small)
                }
                if let app = model.draft.app {
                    LabeledContent("확인됨") {
                        Text("\(app.name) · \(app.formattedPrice ?? (app.isFree ? "무료" : ""))")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("전달 방식") {
                Picker("방식", selection: model.kindSelection) {
                    ForEach(GiftLinkKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                if let notice = model.autoFillNotice {
                    Label(notice, systemImage: "wand.and.stars")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(model.draft.kind.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if model.draft.kind.requiresCode {
                    TextField("코드", text: $model.draft.code)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    if ledger.isCodeUsed(model.draft.code) {
                        Label("이미 보낸 코드입니다.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Toggle("만료일 표시", isOn: $hasExpiry)
                        .onChange(of: hasExpiry) { _, isOn in
                            model.draft.expiry = isOn
                                ? Calendar.current.date(byAdding: .day, value: 28, to: Date())
                                : nil
                        }

                    if hasExpiry {
                        DatePicker(
                            "만료일",
                            selection: Binding(
                                get: { model.draft.expiry ?? Date() },
                                set: { model.draft.expiry = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }
            }

            Section("카드") {
                TextField("문구 (예: 생일 축하해요)", text: $model.draft.occasion)
                TextField("받는 사람", text: $model.draft.recipient)
                TextField("보내는 사람", text: $model.draft.sender)

                VStack(alignment: .leading, spacing: 4) {
                    Text("메시지").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $model.draft.message)
                        .font(.system(size: 13))
                        .frame(height: 76)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.25))
                        )
                    Text("세 줄까지 카드에 들어갑니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ThemePicker(selection: $model.draft.theme)

                Toggle("카드에 코드 표시", isOn: $model.draft.showCodeOnCard)
                    .disabled(!model.draft.kind.requiresCode)
                Toggle("QR 코드 넣기", isOn: $model.draft.showQRCode)
            }

            Section {
                DisclosureGroup("캠페인 추적 (선택)") {
                    TextField("Provider token (pt)", text: $model.draft.providerToken)
                    TextField("Campaign code (ct)", text: $model.draft.campaignCode)
                    Text("App Analytics에서 유입을 구분하고 싶을 때만 채우세요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = model.errorMessage {
                Section {
                    Label(error, systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Preview chrome

    private var previewBackdrop: some View {
        LinearGradient(
            colors: [Color(nsColor: .windowBackgroundColor), Color(nsColor: .underPageBackgroundColor)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Tells you what dragging does, and what you've done, without a manual.
    private var layoutBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.draw")
                .foregroundStyle(.secondary)

            Text(layoutHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Button("배치 초기화") { model.resetLayout() }
                .controlSize(.small)
                .disabled(model.layout.isStandard)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.4))
    }

    private var layoutHint: String {
        guard let block = model.selectedBlock else {
            return model.layout.isStandard
                ? "카드 위의 요소를 끌어서 옮겨 보세요. PNG로 내보낼 때도 그대로 나갑니다."
                : "배치를 바꿨습니다. 내보내는 이미지에도 그대로 적용됩니다."
        }
        return "\(block.label) 선택됨 — 끌어서 이동(방향키 미세 조정), 모서리 손잡이나 +/− 키로 크기 조절"
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            if !model.link.isEmpty {
                HStack(spacing: 8) {
                    Text(model.link)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("열기") { model.openLink() }
                        .controlSize(.small)
                }
            }

            HStack(spacing: 10) {
                // One action carries both halves — the link that works and the
                // wrapping that makes it a gift.
                ShareAnchor { view in model.share(from: view) } label: {
                    Label("공유", systemImage: "square.and.arrow.up")
                }
                .frame(width: 88, height: 22)

                Button("메시지 복사") { model.copyMessage() }
                Button("이미지 복사") { model.copyCardImage() }

                Menu("더보기") {
                    Button("선물 링크 복사") { model.copyGiftLink() }
                    Button("선물 페이지 미리보기") { model.openGiftLink() }
                    Divider()
                    Button("리딤 링크 복사") { model.copyLink() }
                    Button("리딤 링크 열기") { model.openLink() }
                    Divider()
                    Button("PNG 저장") { model.saveCardImage() }
                    Button("낱장 HTML 저장") { model.saveGiftPage() }
                }
                .frame(width: 92)

                Spacer()
                Button("보낸 기록에 추가") { model.recordIssued(into: ledger) }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
            .disabled(!model.draft.isReady)

            if let status = model.status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(.bar)
    }
}

// MARK: - Share button

/// A button that can hand the share sheet a real `NSView` to hang off, which
/// `NSSharingServicePicker` needs and SwiftUI won't give up on its own.
@MainActor
struct ShareAnchor<Label: View>: NSViewRepresentable {
    let action: (NSView) -> Void
    @ViewBuilder let label: () -> Label

    func makeNSView(context: Context) -> NSView {
        let host = NSHostingView(
            rootView: Button(action: { [weak coordinator = context.coordinator] in
                guard let view = coordinator?.view else { return }
                action(view)
            }, label: label)
        )
        host.translatesAutoresizingMaskIntoConstraints = false
        context.coordinator.view = host
        return host
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        weak var view: NSView?
    }
}

// MARK: - Theme swatches

@MainActor
struct ThemePicker: View {
    @Binding var selection: GiftTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("색상").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(GiftTheme.allCases) { theme in
                    Button {
                        selection = theme
                    } label: {
                        Circle()
                            .fill(theme.gradient)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .stroke(Color.accentColor, lineWidth: selection == theme ? 2.5 : 0)
                                    .padding(-4)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(theme.displayName)
                }
            }
        }
    }
}
