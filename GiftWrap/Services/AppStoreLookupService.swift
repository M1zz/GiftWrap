import Foundation
import AppKit

enum LookupError: LocalizedError {
    case badInput
    case notFound
    case network(String)

    var errorDescription: String? {
        switch self {
        case .badInput:
            return "App Store 링크나 숫자 ID를 넣어주세요."
        case .notFound:
            return "해당 스토어프론트에서 앱을 찾지 못했습니다. 국가 코드를 확인해 주세요."
        case .network(let message):
            return "앱 정보를 불러오지 못했습니다. \(message)"
        }
    }
}

/// Reads public product metadata from the iTunes Lookup API. No auth, no App Store Connect key.
struct AppStoreLookupService {

    var storefront: String = "kr"

    func lookup(_ input: String) async throws -> AppStoreApp {
        guard let appleID = RedeemLinkBuilder.appleID(from: input) else { throw LookupError.badInput }

        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id", value: String(appleID)),
            URLQueryItem(name: "country", value: storefront),
            URLQueryItem(name: "entity", value: "software")
        ]
        guard let url = components.url else { throw LookupError.badInput }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(LookupResponse.self, from: data)
            guard let app = response.results.compactMap({ $0.toApp() }).first else {
                throw LookupError.notFound
            }
            return app
        } catch let error as LookupError {
            throw error
        } catch {
            throw LookupError.network(error.localizedDescription)
        }
    }

    func artwork(for app: AppStoreApp) async -> NSImage? {
        guard let url = app.artworkURL else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return NSImage(data: data)
    }

    func artworkData(for app: AppStoreApp) async -> Data? {
        guard let url = app.artworkURL else { return nil }
        return try? await URLSession.shared.data(from: url).0
    }
}
