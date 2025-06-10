//
//  XboxKit.swift
//  XboxKit
//
//  Created by Felix Pultar on 26.05.2025.
//

import Foundation
import Logging

// MARK: - API types

public struct XboxGame: Equatable, Codable, Sendable {
    
    public init(productId: String, productTitle: String, productDescription: String?, developerName: String?, publisherName: String?, shortTitle: String?, sortTitle: String?, shortDescription: String?, imageDescriptors: [XboxImageDescriptor]?) {
        self.productId = productId
        self.productTitle = productTitle
        self.productDescription = productDescription
        self.developerName = developerName
        self.publisherName = publisherName
        self.shortTitle = shortTitle
        self.sortTitle = sortTitle
        self.shortDescription = shortDescription
        self.imageDescriptors = imageDescriptors
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
}

public struct XboxImageDescriptor: Equatable, Sendable, Codable {
    
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

public enum XboxMarketplace {
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
            let localizedProperties: [GamePassProductLocalizedProperty]
            
            struct GamePassProductLocalizedProperty: Codable {
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
