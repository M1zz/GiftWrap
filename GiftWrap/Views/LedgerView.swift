import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct LedgerView: View {
    @EnvironmentObject private var ledger: GiftLedger
    @State private var search = ""

    private var filtered: [GiftRecord] {
        guard !search.isEmpty else { return ledger.records }
        let needle = search.lowercased()
        return ledger.records.filter {
            $0.appName.lowercased().contains(needle)
                || $0.recipient.lowercased().contains(needle)
                || $0.code.lowercased().contains(needle)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if ledger.records.isEmpty {
                emptyState
            } else {
                table
            }
            footer
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "shippingbox")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text("아직 보낸 선물이 없습니다.")
                .font(.headline)
            Text("카드를 만든 뒤 ‘보낸 기록에 추가’를 누르면 여기에 쌓입니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var table: some View {
        Table(filtered) {
            TableColumn("보낸 날짜") { record in
                Text(record.issuedAt, format: .dateTime.year().month().day())
            }
            .width(min: 100, ideal: 110)

            TableColumn("앱", value: \.appName)

            TableColumn("받는 사람") { record in
                Text(record.recipient.isEmpty ? "—" : record.recipient)
            }

            TableColumn("코드") { record in
                Text(record.code.isEmpty ? "—" : record.code)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }

            TableColumn("방식") { record in
                Text(record.kind.label)
            }

            TableColumn("사용됨") { record in
                Toggle("", isOn: Binding(
                    get: { record.redeemed },
                    set: { _ in ledger.toggleRedeemed(record) }
                ))
                .labelsHidden()
            }
            .width(60)

            TableColumn("") { record in
                Button {
                    GiftExporter.copy(text: record.link)
                } label: {
                    Image(systemName: "link")
                }
                .buttonStyle(.borderless)
                .help("링크 복사")
            }
            .width(34)
        }
    }

    private var footer: some View {
        HStack {
            TextField("검색", text: $search)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)
            Spacer()
            Text("\(ledger.records.count)건")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("CSV 내보내기") {
                GiftExporter.save(
                    data: Data(ledger.csv().utf8),
                    suggestedName: "giftwrap-ledger.csv",
                    type: .commaSeparatedText
                )
            }
            .disabled(ledger.records.isEmpty)
        }
        .padding(14)
        .background(.bar)
    }
}
