import Foundation

/// Metadata for a single App Store product, resolved from the public iTunes Lookup API.
struct AppStoreApp: Codable, Identifiable, Hashable {
    let id: Int              // trackId — the Apple ID used in redeem URLs
    let name: String
    let developer: String
    let artworkURL: URL?
    let productURL: URL?
    let formattedPrice: String?
    let genre: String?
    let isFree: Bool

    var appleIDString: String { String(id) }
}

// MARK: - iTunes Lookup response

struct LookupResponse: Decodable {
    let resultCount: Int
    let results: [LookupResult]
}

struct LookupResult: Decodable {
    let trackId: Int?
    let trackName: String?
    let artistName: String?
    let artworkUrl512: String?
    let artworkUrl100: String?
    let trackViewUrl: String?
    let formattedPrice: String?
    let price: Double?
    let primaryGenreName: String?
    let kind: String?

    func toApp() -> AppStoreApp? {
        guard let trackId, let trackName else { return nil }
        let artwork = artworkUrl512 ?? artworkUrl100
        return AppStoreApp(
            id: trackId,
            name: trackName,
            developer: artistName ?? "",
            artworkURL: artwork.flatMap(URL.init(string:)),
            productURL: trackViewUrl.flatMap(URL.init(string:)),
            formattedPrice: formattedPrice,
            genre: primaryGenreName,
            isFree: (price ?? 0) == 0
        )
    }
}
