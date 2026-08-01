import SwiftUI

@MainActor
struct ContentView: View {
    @StateObject private var model = ComposerModel()
    @ObservedObject private var loc = Localization.shared

    var body: some View {
        TabView {
            ComposerView(model: model)
                .tabItem { Label(loc.s(T.composerTab), systemImage: "gift") }

            BatchView(model: model)
                .tabItem { Label(loc.s(T.batchTab), systemImage: "square.stack.3d.up") }

            LedgerView()
                .tabItem { Label(loc.s(T.ledgerTab), systemImage: "list.bullet.rectangle") }
        }
        .padding(12)
        // Status lines and lookup errors were written in the language that was current
        // when they happened, and there's nothing to re-run to translate them. Clearing
        // them beats leaving a sentence behind in the language you just switched away from.
        .onChange(of: loc.language) { _, _ in
            model.status = nil
            model.errorMessage = nil
        }
    }
}

// MARK: - Composer

@MainActor
struct ComposerView: View {
    @ObservedObject var model: ComposerModel
    @EnvironmentObject private var ledger: GiftLedger
    @ObservedObject private var loc = Localization.shared
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
                    selection: $model.selectedBlock
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
            Section(loc.s(T.appSection)) {
                HStack {
                    TextField(loc.s(T.appQueryField), text: $model.query)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { Task { await model.lookup() } }
                    Button(loc.s(T.lookUp)) { Task { await model.lookup() } }
                        .disabled(model.query.isEmpty || model.isLoading)
                }
                Picker(loc.s(T.storefront), selection: $model.storefront) {
                    Text(loc.s(T.storeKR)).tag("kr")
                    Text(loc.s(T.storeUS)).tag("us")
                    Text(loc.s(T.storeJP)).tag("jp")
                    Text(loc.s(T.storeGB)).tag("gb")
                }
                if model.isLoading {
                    ProgressView().controlSize(.small)
                }
                if let app = model.draft.app {
                    LabeledContent(loc.s(T.resolved)) {
                        Text("\(app.name) · \(app.formattedPrice ?? (app.isFree ? loc.s(T.free) : ""))")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(loc.s(T.deliverySection)) {
                Picker(loc.s(T.deliveryKind), selection: model.kindSelection) {
                    ForEach(GiftLinkKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                // The segmented style is an NSSegmentedControl underneath, and it keeps
                // the titles it was first built with: the cases' identities don't change
                // when the language does, so nothing tells it to re-read them. Keying it
                // to the language rebuilds the control instead.
                .id(loc.language)

                if let notice = model.autoFillNotice {
                    Label(notice, systemImage: "wand.and.stars")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(model.draft.kind.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if model.draft.kind.requiresCode {
                    TextField(loc.s(T.codeField), text: $model.draft.code)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    if ledger.isCodeUsed(model.draft.code) {
                        Label(loc.s(T.codeAlreadySent), systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Toggle(loc.s(T.showExpiry), isOn: $hasExpiry)
                        .onChange(of: hasExpiry) { _, isOn in
                            model.draft.expiry = isOn
                                ? Calendar.current.date(byAdding: .day, value: 28, to: Date())
                                : nil
                        }

                    if hasExpiry {
                        DatePicker(
                            loc.s(T.expiryField),
                            selection: Binding(
                                get: { model.draft.expiry ?? Date() },
                                set: { model.draft.expiry = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }
            }

            Section(loc.s(T.cardSection)) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc.s(T.cardStyle)).font(.caption).foregroundStyle(.secondary)
                    CardStylePicker(selection: model.styleSelection, theme: model.draft.theme)
                    Text(loc.s(T.cardStyleHint))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // The one choice on this form that isn't about the interface: it decides
                // what language the recipient is spoken to in.
                VStack(alignment: .leading, spacing: 4) {
                    Picker(loc.s(T.cardLanguage), selection: model.cardLanguageSelection) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(loc.s(T.cardLanguageHint))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                TextField(
                    loc.s(T.occasionField),
                    text: $model.draft.occasion,
                    prompt: Text(C.defaultOccasion.text(model.draft.cardLanguage))
                )
                TextField(loc.s(T.recipient), text: $model.draft.recipient)
                TextField(loc.s(T.sender), text: $model.draft.sender)

                VStack(alignment: .leading, spacing: 4) {
                    Text(loc.s(T.message)).font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $model.draft.message)
                        .font(.system(size: 13))
                        .frame(height: 76)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.25))
                        )
                    Text(loc.s(T.messageLimit))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ThemePicker(selection: $model.draft.theme)

                Toggle(loc.s(T.showCode), isOn: $model.draft.showCodeOnCard)
                    .disabled(!model.draft.kind.requiresCode)
                Toggle(loc.s(T.showQR), isOn: $model.draft.showQRCode)
            }

            Section {
                DisclosureGroup(loc.s(T.campaignGroup)) {
                    TextField("Provider token (pt)", text: $model.draft.providerToken)
                    TextField("Campaign code (ct)", text: $model.draft.campaignCode)
                    Text(loc.s(T.campaignHint))
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

            Button(loc.s(T.resetLayout)) { model.resetLayout() }
                .controlSize(.small)
                .disabled(model.layout.isDefault)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.4))
    }

    private var layoutHint: String {
        guard let block = model.selectedBlock else {
            return loc.s(model.layout.isDefault ? T.layoutIdle : T.layoutChanged)
        }
        return loc.s(T.layoutSelected(block.label))
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
                    Button(loc.s(T.open)) { model.openLink() }
                        .controlSize(.small)
                }
            }

            copySection

            // Sending. Every way to hand the gift over, in one row and none of it hidden.
            HStack(spacing: 8) {
                // One action carries both halves — the link that works and the
                // wrapping that makes it a gift.
                ShareAnchor { view in model.share(from: view) } label: {
                    Label(loc.s(T.share), systemImage: "square.and.arrow.up")
                }
                .frame(width: 96, height: 28)

                Button(loc.s(T.copyMessage)) { model.copyMessage() }
                Button(loc.s(T.copyImage)) { model.copyCardImage() }
                Spacer()
            }
            .disabled(!model.draft.isReady)

            // Checking and keeping.
            HStack(spacing: 8) {
                Button(loc.s(T.previewReceived)) { model.openGiftLink() }
                Button(loc.s(T.savePNG)) { model.saveCardImage() }
                Button(loc.s(T.saveHTML)) { model.saveGiftPage() }
                Spacer()
                Button(loc.s(T.addToLedger)) { model.recordIssued(into: ledger) }
                    .keyboardShortcut(.return, modifiers: .command)
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

    /// Two different links can end up on the clipboard, so neither button says just
    /// "Copy" — each names the link it copies, and both sit under one heading where
    /// they can't be missed.
    private var copySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(loc.s(T.copyLinkHeading), systemImage: "link")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                CopyLinkButton(
                    title: loc.s(T.copyGiftLink),
                    subtitle: loc.s(T.copyGiftLinkSub),
                    systemImage: "gift",
                    isProminent: true
                ) { model.copyGiftLink() }
                .disabled(model.giftPageURL == nil)

                CopyLinkButton(
                    title: loc.s(T.copyRedeemLink),
                    subtitle: loc.s(T.copyRedeemLinkSub),
                    systemImage: "arrow.up.right.square",
                    isProminent: false
                ) { model.copyLink() }
                .disabled(model.link.isEmpty)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.22), lineWidth: 1)
        )
    }
}

// MARK: - Copy buttons

/// A copy action big enough to read at a glance: what it copies on the first line,
/// what that link actually does on the second.
@MainActor
private struct CopyLinkButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isProminent: Bool
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 10))
                        .opacity(0.75)
                }
                .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.7)
            }
            .foregroundStyle(isProminent ? AnyShapeStyle(.white) : AnyShapeStyle(Color.primary))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(
                        isProminent ? Color.clear : Color.primary.opacity(0.18),
                        lineWidth: 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { isHovering = isEnabled && $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .help("\(title) — \(subtitle)")
    }

    private var background: some View {
        Group {
            if isProminent {
                Color.accentColor
            } else {
                Color.primary.opacity(0.06)
            }
        }
        .brightness(isHovering ? (isProminent ? 0.06 : 0.0) : 0)
        .overlay(isHovering && !isProminent ? Color.primary.opacity(0.05) : Color.clear)
    }
}

// MARK: - Share button

/// A button that can hand the share sheet a real `NSView` to hang off, which
/// `NSSharingServicePicker` needs and SwiftUI won't give up on its own.
@MainActor
struct ShareAnchor<Label: View>: NSViewRepresentable {
    let action: (NSView) -> Void
    @ViewBuilder let label: () -> Label

    func makeNSView(context: Context) -> NSHostingView<AnyView> {
        let host = NSHostingView(rootView: button(coordinator: context.coordinator))
        host.translatesAutoresizingMaskIntoConstraints = false
        context.coordinator.view = host
        return host
    }

    /// Hands the hosting view a freshly built button.
    ///
    /// `label` is a value captured when the representable was made, so a hosting view
    /// left alone keeps the words it was first given — which is how the share button
    /// stayed in the previous language after a switch.
    func updateNSView(_ nsView: NSHostingView<AnyView>, context: Context) {
        nsView.rootView = button(coordinator: context.coordinator)
    }

    private func button(coordinator: Coordinator) -> AnyView {
        AnyView(
            Button(action: { [weak coordinator] in
                guard let view = coordinator?.view else { return }
                action(view)
            }, label: label)
            // Sharing is what this pane is for, so it carries the emphasis.
            .buttonStyle(.borderedProminent)
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        weak var view: NSView?
    }
}

// MARK: - Style thumbnails

/// Picks one of the five card designs.
///
/// The thumbnails are schematics, not miniature renders: five live `GiftCardView`s
/// would each build a QR and an icon to be looked at a centimetre wide. Bars where the
/// blocks go carry the one thing being chosen — the shape of the card — and stay
/// legible at this size, which a real render would not.
@MainActor
struct CardStylePicker: View {
    @Binding var selection: CardStyle
    let theme: GiftTheme

    @ObservedObject private var loc = Localization.shared

    var body: some View {
        HStack(spacing: 8) {
            ForEach(CardStyle.allCases) { style in
                Button {
                    selection = style
                } label: {
                    VStack(spacing: 4) {
                        thumbnail(style)
                            .frame(width: 76, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(
                                        selection == style ? Color.accentColor : Color.primary.opacity(0.15),
                                        lineWidth: selection == style ? 2.5 : 1
                                    )
                            )

                        Text(loc.s(style.label))
                            .font(.system(size: 10, weight: selection == style ? .semibold : .regular))
                            .foregroundStyle(selection == style ? Color.accentColor : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .help(loc.s(style.label))
            }
        }
    }

    /// The card's shape in miniature: the gradient, then a bar wherever a block sits.
    private func thumbnail(_ style: CardStyle) -> some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack(alignment: .topLeading) {
                theme.gradient
                    .opacity(style == .minimal ? 0.75 : 1)

                ForEach(Array(marks(style).enumerated()), id: \.offset) { _, mark in
                    RoundedRectangle(cornerRadius: mark.round ? 2.5 : 0.8, style: .continuous)
                        .fill(.white.opacity(mark.strong ? 0.95 : 0.5))
                        .frame(width: mark.w * w, height: mark.h * h)
                        .offset(x: mark.x * w, y: mark.y * h)
                }

                if style.hasPerforation {
                    Rectangle()
                        .fill(.white.opacity(0.55))
                        .frame(width: 1, height: h * 0.74)
                        .offset(x: CardStyle.perforationX * w, y: h * 0.13)
                }
            }
        }
    }

    /// One bar on a thumbnail, in fractions of it.
    private struct Mark {
        var x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat
        var strong = false
        var round = false
    }

    /// Roughly where each style puts things — the icon, the name, the message, and the
    /// code and QR at the bottom. Traced from the real placements, not measured from
    /// them: a thumbnail wants the gist, and the gist survives the block sizes changing.
    private func marks(_ style: CardStyle) -> [Mark] {
        switch style {
        case .classic:
            return [
                Mark(x: 0.06, y: 0.09, w: 0.16, h: 0.05),
                Mark(x: 0.06, y: 0.21, w: 0.17, h: 0.27, strong: true, round: true),
                Mark(x: 0.27, y: 0.25, w: 0.34, h: 0.09, strong: true),
                Mark(x: 0.27, y: 0.38, w: 0.22, h: 0.05),
                Mark(x: 0.06, y: 0.55, w: 0.52, h: 0.05),
                Mark(x: 0.06, y: 0.64, w: 0.40, h: 0.05),
                Mark(x: 0.06, y: 0.80, w: 0.24, h: 0.05),
                Mark(x: 0.56, y: 0.76, w: 0.18, h: 0.08, round: true),
                Mark(x: 0.80, y: 0.70, w: 0.14, h: 0.22, strong: true, round: true)
            ]
        case .centered:
            return [
                Mark(x: 0.42, y: 0.09, w: 0.16, h: 0.05),
                Mark(x: 0.42, y: 0.18, w: 0.16, h: 0.25, strong: true, round: true),
                Mark(x: 0.32, y: 0.48, w: 0.36, h: 0.08, strong: true),
                Mark(x: 0.40, y: 0.59, w: 0.20, h: 0.04),
                Mark(x: 0.26, y: 0.68, w: 0.48, h: 0.04),
                Mark(x: 0.38, y: 0.78, w: 0.24, h: 0.08, round: true),
                Mark(x: 0.06, y: 0.80, w: 0.16, h: 0.05),
                Mark(x: 0.82, y: 0.72, w: 0.13, h: 0.20, strong: true, round: true)
            ]
        case .ticket:
            return [
                Mark(x: 0.06, y: 0.09, w: 0.15, h: 0.05),
                Mark(x: 0.06, y: 0.21, w: 0.16, h: 0.26, strong: true, round: true),
                Mark(x: 0.26, y: 0.25, w: 0.30, h: 0.09, strong: true),
                Mark(x: 0.26, y: 0.38, w: 0.20, h: 0.05),
                Mark(x: 0.06, y: 0.56, w: 0.48, h: 0.05),
                Mark(x: 0.06, y: 0.65, w: 0.34, h: 0.05),
                Mark(x: 0.06, y: 0.80, w: 0.22, h: 0.05),
                Mark(x: 0.775, y: 0.28, w: 0.15, h: 0.24, strong: true, round: true),
                Mark(x: 0.755, y: 0.60, w: 0.19, h: 0.07, round: true)
            ]
        case .poster:
            return [
                Mark(x: 0.06, y: 0.09, w: 0.10, h: 0.15, strong: true, round: true),
                Mark(x: 0.06, y: 0.30, w: 0.62, h: 0.16, strong: true),
                Mark(x: 0.06, y: 0.51, w: 0.40, h: 0.07),
                Mark(x: 0.06, y: 0.63, w: 0.50, h: 0.04),
                Mark(x: 0.06, y: 0.80, w: 0.22, h: 0.05),
                Mark(x: 0.56, y: 0.76, w: 0.18, h: 0.08, round: true),
                Mark(x: 0.80, y: 0.70, w: 0.14, h: 0.22, strong: true, round: true)
            ]
        case .minimal:
            return [
                Mark(x: 0.09, y: 0.14, w: 0.13, h: 0.035),
                Mark(x: 0.09, y: 0.23, w: 0.12, h: 0.19, strong: true, round: true),
                Mark(x: 0.09, y: 0.46, w: 0.30, h: 0.06),
                Mark(x: 0.09, y: 0.57, w: 0.18, h: 0.035),
                Mark(x: 0.09, y: 0.66, w: 0.42, h: 0.035),
                Mark(x: 0.09, y: 0.79, w: 0.20, h: 0.035),
                Mark(x: 0.56, y: 0.76, w: 0.17, h: 0.07, round: true),
                Mark(x: 0.81, y: 0.70, w: 0.13, h: 0.21, round: true)
            ]
        }
    }
}

// MARK: - Theme swatches

@MainActor
struct ThemePicker: View {
    @Binding var selection: GiftTheme
    @ObservedObject private var loc = Localization.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(loc.s(T.colour)).font(.caption).foregroundStyle(.secondary)
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
