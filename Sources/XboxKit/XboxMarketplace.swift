//
//  XboxKit.swift
//  XboxKit
//
//  Created by Felix Pultar on 26.05.2025.
//

import Foundation
import Logging

// MARK: - API types

public struct XboxGame: Equatable, Sendable, Codable, Hashable {
    
    public init(productId: String, productTitle: String, productDescription: String?, developerName: String?, publisherName: String?, shortTitle: String?, sortTitle: String?, shortDescription: String?, imageDescriptors: [XboxImageDescriptor]?, reviews: GameReview? = nil, playtimes: GamePlayTime? = nil) {
        self.productId = productId
        self.productTitle = productTitle
        self.productDescription = productDescription
        self.developerName = developerName
        self.publisherName = publisherName
        self.shortTitle = shortTitle
        self.sortTitle = sortTitle
        self.shortDescription = shortDescription
        self.imageDescriptors = imageDescriptors
        self.reviews = reviews
        self.playtime = playtimes
    }
    
    public let productId: String
    public let productTitle: String
    public let productDescription: String?
    public let developerName: String?
    public let publisherName: String?
    public let shortTitle: String?
    public let sortTitle: String?
    public let shortDescription: String?
    public let imageDescriptors: [XboxImageDescriptor]?
    public let reviews: GameReview?
    public let playtime: GamePlayTime?
}

public struct XboxImageDescriptor: Equatable, Sendable, Codable, Hashable {
    
    public init(fileId: String?, height: Int?, width: Int?, uri: String?, imagePurpose: String?, imagePositionInfo: String?) {
        self.fileId = fileId
        self.height = height
        self.width = width
        self.uri = uri
        self.imagePurpose = imagePurpose
        self.imagePositionInfo = imagePositionInfo
    }
    
    public let fileId: String?
    public let height: Int?
    public let width: Int?
    public let uri: String?
    public let imagePurpose: String?
    public let imagePositionInfo: String?
    
    enum CodingKeys: String, CodingKey {
        case fileId = "FileId"
        case height = "Height"
        case width = "Width"
        case uri = "Uri"
        case imagePurpose = "ImagePurpose"
        case imagePositionInfo = "ImagePositionInfo"
    }
}

public struct GameReview: Equatable, Sendable, Codable, Hashable {
    public let score: Double?
    public let recentScore: Double?
    public let totalReviews: Int?
    
    public init(score: Double?, recentScore: Double?, totalReviews: Int?) {
        self.score = score
        self.recentScore = recentScore
        self.totalReviews = totalReviews
    }
    
    public var summary: String? {
        generateSummary(for: score)
    }
    
    public var recentSummary: String? {
        generateSummary(for: recentScore)
    }
    
    private func generateSummary(for score: Double?) -> String? {
        guard let score = score, let totalReviews = totalReviews else {
            return nil
        }
        
        switch (score, totalReviews) {
        case (95...100, 500...):
            return "Overwhelmingly Positive"
        case (85...100, 50...):
            return "Very Positive"
        case (80...100, 10...):
            return "Positive"
        case (70...79, 10...):
            return "Mostly Positive"
        case (40...69, 10...):
            return "Mixed"
        case (20...39, 10...):
            return "Mostly Negative"
        case (0...19, 500...):
            return "Overwhelmingly Negative"
        case (0...19, 50...):
            return "Very Negative"
        case (0...19, 10...):
            return "Negative"
        default:
            // Not enough reviews for a summary
            return nil
        }
    }
    
    // Convenience computed property to check if there's enough data
    public var hasValidData: Bool {
        return score != nil && totalReviews != nil && totalReviews! >= 10
    }
    
    // Convenience computed property for color coding in UI
    public var sentiment: ReviewSentiment? {
        guard let score = score else { return nil }
        
        switch score {
        case 80...100:
            return .positive
        case 40...79:
            return .mixed
        case 0..<40:
            return .negative
        default:
            return nil
        }
    }
    
    public enum ReviewSentiment {
        case positive
        case mixed
        case negative
    }
}

public struct GamePlayTime: Equatable, Sendable, Codable, Hashable {
    public let mainStory: Double?
    public let mainPlusExtras: Double?
    public let completionist: Double?
    
    public init(mainStory: Double?, mainPlusExtras: Double?, completionist: Double?) {
        self.mainStory = mainStory
        self.mainPlusExtras = mainPlusExtras
        self.completionist = completionist
    }
}

public enum XboxMarketplace {
    
    // MARK: - API functions
    
    public static func queryXboxMarketplace(query: String, language: Language, market: Market, session: URLSession = .shared) async throws -> [String] {
        guard !query.isEmpty else { throw XboxError.invalidInput("Query string must not be empty") }
        let baseURL = "https://displaycatalog.mp.microsoft.com/v7.0/productFamilies/autosuggest"
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "languages", value: language.localeCode),
            URLQueryItem(name: "market", value: market.isoCode),
            URLQueryItem(name: "productFamilyNames", value: "Games"),
            URLQueryItem(name: "query", value: query),
        ]
        
        guard let url = components?.url else { throw XboxError.invalidURL }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        let response = try decoder.decode(XboxQueryResponse.self, from: data)
        let productIds = response.allProducts.compactMap(\.productId)
        return productIds
    }
    
    public static func fetchProductInformation(
        gameIds: [String], language: Language, market: Market, session: URLSession = .shared
    ) async throws -> [XboxGame] {
        guard !gameIds.isEmpty else { throw XboxError.invalidInput("At least one game ID must be provided") }

        let url = try XboxMarketplace.buildProductInformationURL(gameIds: gameIds, language: language, market: market)
        let products = try await XboxMarketplace.fetchAndDecodeProductInformation(url: url, session: session)

        return products.compactMap { product in
            guard let localizedProperties = product.localizedProperties.first else { return nil }
            return XboxGame(
                productId: product.productId, productTitle: localizedProperties.productTitle,
                productDescription: localizedProperties.productDescription,
                developerName: localizedProperties.developerName, publisherName: localizedProperties.publisherName,
                shortTitle: localizedProperties.shortTitle, sortTitle: localizedProperties.sortTitle,
                shortDescription: localizedProperties.shortDescription, imageDescriptors: localizedProperties.images)
        }
    }
    
    private static func buildProductInformationURL(gameIds: [String], language: Language, market: Market) throws -> URL {
        var components = URLComponents(string: "https://displaycatalog.mp.microsoft.com/v7.0/products")
        components?.queryItems = [
            URLQueryItem(name: "bigIds", value: gameIds.joined(separator: ",")),
            URLQueryItem(name: "languages", value: language.localeCode), URLQueryItem(name: "market", value: market.isoCode),
        ]

        guard let url = components?.url else { throw XboxError.invalidURL }

        return url
    }

    private static func fetchAndDecodeProductInformation(url: URL, session: URLSession) async throws
    -> [XboxProductResponse.XboxProduct]
    {
        let (data, response) = try await session.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw XboxError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        do {
            let productResponse = try decoder.decode(XboxProductResponse.self, from: data)
            return productResponse.products
        } catch { throw XboxError.jsonParsingError(underlying: error) }
    }
    
    struct XboxProductResponse: Codable {
        let products: [XboxProduct]
        
        struct XboxProduct: Codable {
            let productId: String
            let localizedProperties: [XboxProductLocalizedProperty]
            
            struct XboxProductLocalizedProperty: Codable {
                let productTitle: String
                let productDescription: String
                let developerName: String?
                let publisherName: String?
                let shortTitle: String?
                let sortTitle: String?
                let shortDescription: String?
                let images: [XboxImageDescriptor]?

                enum CodingKeys: String, CodingKey {
                    case productTitle = "ProductTitle"
                    case productDescription = "ProductDescription"
                    case developerName = "DeveloperName"
                    case publisherName = "PublisherName"
                    case shortTitle = "ShortTitle"
                    case sortTitle = "SortTitle"
                    case shortDescription = "ShortDescription"
                    case images = "Images"
                }
            }

            enum CodingKeys: String, CodingKey {
                case productId = "ProductId"
                case localizedProperties = "LocalizedProperties"
            }
        }

        enum CodingKeys: String, CodingKey { case products = "Products" }
    }
    
    struct XboxQueryResponse: Codable {
        let results: [XboxQueryResultType]
        let totalResultCount: Int
        
        struct XboxQueryResultType: Codable {
            let productFamilyName: String
            let products: [XboxProductType]
            
            enum CodingKeys: String, CodingKey {
                case productFamilyName = "ProductFamilyName"
                case products = "Products"
            }
        }
        
        struct XboxProductType: Codable, Identifiable {
            let backgroundColor: String
            let height: Int
            let width: Int
            let imageType: String
            let platformProperties: [String]
            let icon: String
            let productId: String
            let type: String
            let title: String
            
            var id: String { productId }
            
            enum CodingKeys: String, CodingKey {
                case backgroundColor = "BackgroundColor"
                case height = "Height"
                case width = "Width"
                case imageType = "ImageType"
                case platformProperties = "PlatformProperties"
                case icon = "Icon"
                case productId = "ProductId"
                case type = "Type"
                case title = "Title"
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case results = "Results"
            case totalResultCount = "TotalResultCount"
        }
        
        var allProducts: [XboxProductType] {
            results.flatMap { $0.products }
        }
    }
    
}


// MARK: - Error definitions

public enum XboxError: LocalizedError {
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
