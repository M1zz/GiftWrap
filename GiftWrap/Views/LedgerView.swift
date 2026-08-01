import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct LedgerView: View {
    @EnvironmentObject private var ledger: GiftLedger
    @ObservedObject private var loc = Localization.shared
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
            Text(loc.s(T.ledgerEmptyTitle))
                .font(.headline)
            Text(loc.s(T.ledgerEmptyBody))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var table: some View {
        Table(filtered) {
            TableColumn(loc.s(T.ledgerDate)) { record in
                Text(record.issuedAt, format: .dateTime.year().month().day())
            }
            .width(min: 100, ideal: 110)

            TableColumn(loc.s(T.ledgerApp), value: \.appName)

            TableColumn(loc.s(T.recipient)) { record in
                Text(record.recipient.isEmpty ? "—" : record.recipient)
            }

            TableColumn(loc.s(T.codeField)) { record in
                Text(record.code.isEmpty ? "—" : record.code)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }

            TableColumn(loc.s(T.ledgerKind)) { record in
                Text(record.kind.label)
            }

            TableColumn(loc.s(T.ledgerRedeemed)) { record in
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
                .help(loc.s(T.ledgerCopyLink))
            }
            .width(34)
        }
    }

    private var footer: some View {
        HStack {
            TextField(loc.s(T.search), text: $search)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)
            Spacer()
            Text(loc.s(T.ledgerCount(ledger.records.count)))
                .font(.callout)
                .foregroundStyle(.secondary)
            Button(loc.s(T.exportCSV)) {
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
