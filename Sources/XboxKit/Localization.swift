//
//  Localization.swift
//  XboxKit
//
//  Created by Felix Pultar on 10.06.2025.
//

import Foundation

public struct Market: Codable, Equatable, Sendable, Hashable {
    public let isoCode: String      // ISO 2-letter code (e.g., "US")
    public let name: String      // English name
    public let threeLetterISO: String?    // ISO 3-letter code (e.g., "USA")
    
    public init(code: String, name: String, code3: String? = nil) {
        self.isoCode = code
        self.name = name
        self.threeLetterISO = code3
    }
}

public struct Language: Codable, Equatable, Sendable, Hashable {
    public let localeCode: String       // Full locale code (e.g., "en-US")
    public let bcp47Tag: String        // BCP47 tag
    public let nativeName: String   // Name in native language
    
    public init(locale: String, bcp47: String, nativeName: String) {
        self.localeCode = locale
        self.bcp47Tag = bcp47
        self.nativeName = nativeName
    }
    
    /// Extract the language code component (e.g., "en" from "en-US")
    public var languageCode: String {
        localeCode.split(separator: "-").first.map(String.init) ?? localeCode
    }
    
    /// Extract the region code component (e.g., "US" from "en-US")
    public var regionCode: String? {
        let components = localeCode.split(separator: "-")
        return components.count > 1 ? String(components.last!) : nil
    }
}

public enum Localization {
    
    // MARK: - Data
    
    /// All supported markets
    public static let markets: [Market] = loadMarkets()
    
    /// All supported languages
    public static let languages: [Language] = loadLanguages()
    
    // MARK: - Lookups
    
    /// Find a market by its ISO code
    public static func market(_ code: String) -> Market? {
        markets.first { $0.isoCode.caseInsensitiveCompare(code) == .orderedSame }
    }
    
    /// Find a language by its locale code
    public static func language(_ locale: String) -> Language? {
        languages.first { $0.localeCode.caseInsensitiveCompare(locale) == .orderedSame }
    }
    
    /// Get all languages available in a specific market
    public static func languages(in market: Market) -> [Language] {
        let upperCode = market.isoCode.uppercased()
        return languages.filter { $0.regionCode?.uppercased() == upperCode }
    }
    
    /// Get all markets where a specific language is spoken
    public static func markets(speaking languageCode: Language) -> [Market] {
        let lowerCode = languageCode.languageCode.lowercased()
        let matchingLocales = languages
            .filter { $0.languageCode.lowercased() == lowerCode }
            .compactMap { $0.regionCode }
        
        return markets.filter { market in
            matchingLocales.contains { $0.caseInsensitiveCompare(market.isoCode) == .orderedSame }
        }
    }
    
    /// Check if a market is supported
    public static func isSupported(market: String) -> Bool {
        markets.contains { $0.isoCode.caseInsensitiveCompare(market) == .orderedSame }
    }

    /// Check if a language locale is supported
    public static func isSupported(locale: String) -> Bool {
        languages.contains { $0.localeCode.caseInsensitiveCompare(locale) == .orderedSame }
    }
    
    public static func isValidMarket(_ market: String, language: String) -> Bool {
        Localization.isSupported(market: market) && Localization.isSupported(locale: language)
    }
    
    /// Get default language for a market (first available)
    public static func defaultLanguage(for marketCode: Market) -> Language? {
        languages(in: marketCode).first
    }
    
    // MARK: - Private Loading
    
    private static func loadMarkets() -> [Market] {
        guard let url = Bundle.module.url(forResource: "market-data", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let items = try? PropertyListDecoder().decode([Market].self, from: data) else {
            fatalError("Failed to load market-data.plist from bundle")
        }
        
        return items.map { item in
            Market(code: item.isoCode, name: item.name, code3: item.threeLetterISO)
        }.sorted { $0.isoCode < $1.isoCode }
    }
    
    private static func loadLanguages() -> [Language] {
        guard let url = Bundle.module.url(forResource: "language-data", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let items = try? PropertyListDecoder().decode([Language].self, from: data) else {
            fatalError("Failed to load language-data.plist from bundle")
        }
        
        return items.map { item in
            Language(locale: item.localeCode, bcp47: item.bcp47Tag, nativeName: item.nativeName)
        }.sorted { $0.localeCode < $1.localeCode }
    }
}
