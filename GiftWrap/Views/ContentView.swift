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
                GiftCardPreview(draft: model.draft, artwork: model.artwork)
                    .padding(28)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(previewBackdrop)

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
                Picker("방식", selection: $model.draft.kind) {
                    ForEach(GiftLinkKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

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
                Button("메시지 복사") { model.copyMessage() }
                Button("링크 복사") { model.copyLink() }
                Button("이미지 복사") { model.copyCardImage() }
                Spacer()
                Button("PNG 저장") { model.saveCardImage() }
                Button("선물 페이지 저장") { model.saveGiftPage() }
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
