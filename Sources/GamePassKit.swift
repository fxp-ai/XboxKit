import ArgumentParser
import Foundation
import Logging

public struct Game: Sendable {
    public let title: String
    public let description: String
}

public struct GameCollection: Sendable {
    public let header: CategoryHeader?
    public let games: [String]
}

public struct CategoryHeader: Codable, Sendable {
    public let siglId: String
    public let title: String
    public let description: String
    public let requiresShuffling: String
    public let imageUrl: URL
}

public enum GamePassCatalog {

    private static let logger = Logger(label: "ai.fxp.gamepass.catalog")

    // All games

    public static let kGamePassConsoleIdentifier = "f6f1f99f-9b49-4ccd-b3bf-4d9767a77f5e"
    public static let kGamePassCoreIdentifier = "34031711-5a70-4196-bab7-45757dc2294e"
    public static let kGamePassStandardIdentifier = "09a72c0d-c466-426a-9580-b78955d8173a"
    public static let kGamePassPcIdentifier = "609d944c-d395-4c0a-9ea4-e9f39b52c1ad"

    // Unsure what these keys are...

    public static let kGamePassPcSecondaryIdentifier = "fdd9e2a7-0fee-49f6-ad69-4354098401ff"
    public static let kGamePassConsoleSecondaryIdentifier = "29a81209-df6f-41fd-a528-2ae6b91f719c"

    // Day one releases

    public static let kConsoleDayOneReleasesIdentifier = "a672552e-fdc2-4ecd-96e9-b8409193f524"
    public static let kPcDayOneReleasesIdentifier = "4b59700c-801f-494a-a34c-842b8c98f154"

    // Most popular

    public static let kConsoleMostPopularIdentifier = "eab7757c-ff70-45af-bfa6-79d3cfb2bf81"
    public static let kPcMostPopularIdentifier = "a884932a-f02b-40c8-a903-a008c23b1df1"
    public static let kGamePassCoreMostPopularIdentifier = "c76e2ddb-345d-4483-981e-d90789fcb46b"
    public static let kGamePassStandardMostPopularIdentifier = "099d5213-25e2-4896-bf09-33432f1c6e66"
    public static let kCloudMostPopularIdentifier = "e7590b22-e299-44db-ae22-25c61405454c"

    // Recently added

    public static let kConsoleRecentlyAddedIdentifier = "f13cf6b4-57e6-4459-89df-6aec18cf0538"
    public static let kPcRecentlyAddedIdentifier = "3fdd7f57-7092-4b65-bd40-5a9dac1b2b84"
    public static let kGamePassStandardRecentlyAddedIdentifier = "d545e21a-d165-4f3f-a95b-b08542b0d2ec"

    // Coming to Game Pass

    public static let kConsoleComingToIdentifier = "095bda36-f5cd-43f2-9ee1-0a72f371fb96"
    public static let kPcComingToIdentifier = "4165f752-d702-49c8-886b-fb57936f6bae"
    public static let kGamePassStandardComingToIdentifier = "83e4b73e-d89c-4b95-8c63-17cdd4b5a7b3"

    // Leaving Game Pass Soon

    public static let kConsoleLeavingSoonIdentifier = "393f05bf-e596-4ef6-9487-6d4fa0eab987"
    public static let kPcLeavingSoonIdentifier = "cc7fc951-d00f-410e-9e02-5e4628e04163"
    public static let kGamePassStandardLeavingSoonIdentifier = "6182c1f2-11b0-4df1-890e-f940fbe33493"

    // Ubisoft and EA

    public static let kUbisoftConsoleIdentifier = "a5a535fb-d926-4141-9ce4-9f6af8ca22e7"
    public static let kUbisoftPcIdentifier = "9c09d734-1c45-4740-ae7f-fd73ff629880"
    public static let kEAPlayConsoleIdentifier = "b8900d09-a491-44cc-916e-32b5acae621b"
    public static let kEAPlayPcIdentifier = "1d33fbb9-b895-4732-a8ca-a55c8b99fa2c"
    public static let kEAPlayTrialConsoleIdentifier = "490f4b6e-a107-4d6a-8398-225ee916e1f2"
    public static let kEAPlayTrialPcIdentifier = "19e5b90a-5a20-4b1d-9dda-6441ca632527"

    public static func fetchGameCollection(
        for siglId: String, language: String, market: String, session: URLSession = .shared
    ) async throws -> GameCollection {
        guard !siglId.isEmpty else { throw GamePassError.invalidInput("SIGL ID cannot be empty") }

        let url = try buildFetchGameCollectionURL(siglId: siglId, language: language, market: market)
        let gameCollection = try await fetchAndDecodeGameCollection(url: url, session: session)
        return gameCollection
    }

    public static func fetchProductInformation(
        gameIds: [String], languages: [String], market: String, session: URLSession = .shared
    ) async throws -> [Game] {
        guard !gameIds.isEmpty else { throw GamePassError.invalidInput("At least one game ID must be provided") }

        let url = try buildProductInformationURL(gameIds: gameIds, languages: languages, market: market)
        let products = try await fetchAndDecodeProductInformation(url: url, session: session)

        return products.compactMap { product in
            guard let localizedProperties = product.localizedProperties.first else { return nil }
            return Game(title: localizedProperties.productTitle, description: localizedProperties.productDescription)
        }
    }

    private static func buildFetchGameCollectionURL(siglId: String, language: String, market: String) throws -> URL {
        var components = URLComponents(string: "https://catalog.gamepass.com/sigls/v2")
        components?.queryItems = [
            URLQueryItem(name: "id", value: siglId), URLQueryItem(name: "language", value: language),
            URLQueryItem(name: "market", value: market),
        ]

        guard let url = components?.url else { throw GamePassError.invalidURL }

        return url
    }

    private static func fetchAndDecodeGameCollection(url: URL, session: URLSession) async throws -> GameCollection {
        let (data, response) = try await session.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw GamePassError.httpError(statusCode: httpResponse.statusCode)
        }

        guard let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] else {
            throw GamePassError.invalidResponseFormat("JSON cannot be deserialized")
        }

        var headerItem: CategoryHeader?
        var gameIds: [String] = []

        for itemDictionary in jsonArray {
            if itemDictionary.keys.contains("title") {
                let headerData = try JSONSerialization.data(withJSONObject: itemDictionary)
                headerItem = try JSONDecoder().decode(CategoryHeader.self, from: headerData)
            } else if let id = itemDictionary["id"] as? String {
                gameIds.append(id)
            } else {
                throw GamePassError.missingRequiredField("JSON contains neither title nor id field")
            }
        }

        return GameCollection(header: headerItem, games: gameIds)
    }

    private static func buildProductInformationURL(gameIds: [String], languages: [String], market: String) throws -> URL
    {
        var components = URLComponents(string: "https://displaycatalog.mp.microsoft.com/v7.0/products")
        components?.queryItems = [
            URLQueryItem(name: "bigIds", value: gameIds.joined(separator: ",")),
            URLQueryItem(name: "languages", value: languages.joined(separator: ",")),
            URLQueryItem(name: "market", value: market),
        ]

        guard let url = components?.url else { throw GamePassError.invalidURL }

        return url
    }

    private static func fetchAndDecodeProductInformation(url: URL, session: URLSession) async throws -> [Product] {
        let (data, response) = try await session.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw GamePassError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        do {
            let productResponse = try decoder.decode(ProductResponse.self, from: data)
            return productResponse.products
        } catch { throw GamePassError.jsonParsingError(underlying: error) }
    }

}

public enum GamePassError: LocalizedError {
    case invalidInput(String)
    case invalidURL
    case httpError(statusCode: Int)
    case jsonParsingError(underlying: Error)
    case invalidResponseFormat(String)
    case missingRequiredField(String)

    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message): return "Invalid input: \(message)"
        case .invalidURL: return "Failed to construct a valid URL"
        case .httpError(let statusCode): return "HTTP error: \(statusCode)"
        case .jsonParsingError(underlying: let error): return "JSON Parsing error: \(error.localizedDescription)"
        case .invalidResponseFormat(let message): return "Invalid response format: \(message)"
        case .missingRequiredField(let message): return "Missing required field: \(message)"
        }
    }

}

private struct ProductResponse: Codable {
    let products: [Product]

    enum CodingKeys: String, CodingKey { case products = "Products" }
}

private struct Product: Codable {
    let localizedProperties: [ProductLocalizedProperty]

    enum CodingKeys: String, CodingKey { case localizedProperties = "LocalizedProperties" }
}

private struct ProductLocalizedProperty: Codable {
    let productTitle: String
    let productDescription: String

    enum CodingKeys: String, CodingKey {
        case productTitle = "ProductTitle"
        case productDescription = "ProductDescription"
    }
}
