import SwiftUI

/// The card itself. Always laid out on a fixed 1000 × 630 canvas so that the on-screen
/// preview and the exported PNG are the same drawing at different scales.
@MainActor
struct GiftCardView: View {

    static let canvas = CGSize(width: 1000, height: 630)

    let draft: GiftDraft
    let artwork: NSImage?

    private var theme: GiftTheme { draft.theme }

    var body: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 24)
                product
                message
                Spacer(minLength: 24)
                footer
            }
            .padding(56)
        }
        .frame(width: Self.canvas.width, height: Self.canvas.height)
        .clipShape(RoundedRectangle(cornerRadius: 56, style: .continuous))
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            theme.gradient

            Circle()
                .fill(theme.blooms[0].opacity(0.55))
                .frame(width: 620, height: 620)
                .blur(radius: 140)
                .offset(x: -300, y: -230)

            Circle()
                .fill(theme.blooms[1].opacity(0.5))
                .frame(width: 700, height: 700)
                .blur(radius: 160)
                .offset(x: 330, y: 250)

            // Single diagonal sheen — the one flourish; everything else stays flat.
            LinearGradient(
                colors: [.white.opacity(0.26), .white.opacity(0.0)],
                startPoint: .topLeading,
                endPoint: .init(x: 0.62, y: 0.55)
            )
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top) {
            Text(draft.occasion.isEmpty ? "선물" : draft.occasion)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .tracking(4.5)
                .textCase(.uppercase)
                .foregroundStyle(theme.ink.opacity(0.85))

            Spacer()

            Text("App Store에서 받기")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.ink.opacity(0.75))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule().stroke(theme.ink.opacity(0.45), lineWidth: 1.2)
                )
        }
    }

    private var product: some View {
        HStack(alignment: .center, spacing: 28) {
            icon
            VStack(alignment: .leading, spacing: 8) {
                Text(draft.app?.name ?? "앱을 불러오세요")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)

                Text(draft.app?.developer ?? "개발자")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.inkSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var icon: some View {
        Group {
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.22)
                    Text(String(draft.app?.name.prefix(1) ?? "?"))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.ink.opacity(0.7))
                }
            }
        }
        .frame(width: 152, height: 152)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(.white.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 26, x: 0, y: 14)
    }

    @ViewBuilder
    private var message: some View {
        if !draft.message.isEmpty {
            Text(draft.message)
                .font(.system(size: 25, weight: .regular, design: .rounded))
                .foregroundStyle(theme.ink.opacity(0.95))
                .lineSpacing(7)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .padding(.top, 34)
                .frame(maxWidth: 700, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                if !draft.recipient.isEmpty {
                    Text("To. \(draft.recipient)")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.ink.opacity(0.9))
                }
                if !draft.sender.isEmpty {
                    Text("From. \(draft.sender)")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.inkSecondary)
                }
                if let expiry = draft.expiry, draft.kind.hasExpiry {
                    Text("\(expiry, format: .dateTime.year().month().day())까지")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.ink.opacity(0.65))
                        .padding(.top, 4)
                }
            }

            Spacer()

            HStack(alignment: .bottom, spacing: 18) {
                if draft.showCodeOnCard, draft.kind.requiresCode, !draft.trimmedCode.isEmpty {
                    Text(draft.trimmedCode)
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(theme.ink)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(style: StrokeStyle(lineWidth: 1.4, dash: [6, 5]))
                                .foregroundStyle(theme.ink.opacity(0.6))
                        )
                }

                if draft.showQRCode,
                   let link = draft.redeemURL?.absoluteString,
                   let qr = QRCodeRenderer.image(from: link, size: 256) {
                    Image(nsImage: qr)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 104, height: 104)
                        .padding(9)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.white)
                        )
                }
            }
        }
    }
}

/// Scales the fixed canvas down to fit whatever space the window gives it.
@MainActor
struct GiftCardPreview: View {
    let draft: GiftDraft
    let artwork: NSImage?

    var body: some View {
        GeometryReader { proxy in
            let scale = min(
                proxy.size.width / GiftCardView.canvas.width,
                proxy.size.height / GiftCardView.canvas.height
            )
            GiftCardView(draft: draft, artwork: artwork)
                .scaleEffect(scale)
                .frame(
                    width: GiftCardView.canvas.width * scale,
                    height: GiftCardView.canvas.height * scale
                )
                .shadow(color: .black.opacity(0.28), radius: 30, x: 0, y: 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
