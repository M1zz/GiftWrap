import Foundation
import Combine

/// Keeps track of which code went to whom, stored as JSON in Application Support.
/// Promo codes are one-time use, so a local record is the difference between a clean
/// campaign and sending the same code to two people.
final class GiftLedger: ObservableObject {

    @Published private(set) var records: [GiftRecord] = []

    private let fileURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = support.appendingPathComponent("GiftWrap", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("ledger.json")
        load()
    }

    // MARK: - Mutations

    func add(_ record: GiftRecord) {
        records.insert(record, at: 0)
        save()
    }

    func remove(_ record: GiftRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    func toggleRedeemed(_ record: GiftRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index].redeemed.toggle()
        save()
    }

    func isCodeUsed(_ code: String) -> Bool {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return false }
        return records.contains { $0.code.uppercased() == normalized }
    }

    func csv() -> String {
        let header = "issued_at,app,apple_id,kind,code,recipient,link,expiry,redeemed"
        let formatter = ISO8601DateFormatter()
        let rows = records.map { record -> String in
            let fields = [
                formatter.string(from: record.issuedAt),
                record.appName,
                String(record.appleID),
                record.kind.rawValue,
                record.code,
                record.recipient,
                record.link,
                record.expiry.map { formatter.string(from: $0) } ?? "",
                record.redeemed ? "yes" : "no"
            ]
            return fields.map(Self.escape).joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - Storage

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        records = (try? decoder.decode([GiftRecord].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
