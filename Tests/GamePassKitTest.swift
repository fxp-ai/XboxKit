//
//  File.swift
//  GamePassKit
//
//  Created by Felix Pultar on 26.05.2025.
//

import Foundation
import XCTest

@testable import GamePassKit

final class AppTests: XCTestCase {

    func testFetchGameCollectionReachable() async throws {
        let gameCollection = try await GamePassCatalog.fetchGameCollection(
            for: GamePassCatalog.kGamePassConsoleIdentifier, language: "en-us", market: "US")
        XCTAssertNotNil(gameCollection, "Game collection should not be nil")
        XCTAssertFalse(gameCollection.games.isEmpty, "Game collection should contain games")
    }

    func testFetchProductInformationReachable() async throws {
        // First get some game IDs
        let gameCollection = try await GamePassCatalog.fetchGameCollection(
            for: GamePassCatalog.kGamePassConsoleIdentifier, language: "en-us", market: "US")

        // Take first 5 games to avoid overwhelming the API
        let testGameIds = Array(gameCollection.games.prefix(5))

        let games = try await GamePassCatalog.fetchProductInformation(
            gameIds: testGameIds, languages: ["en-us"], market: "US")

        XCTAssertFalse(games.isEmpty, "Should return game information")
        XCTAssertTrue(games.allSatisfy { !$0.title.isEmpty }, "All games should have titles")
    }

    func testGameCollectionResponseStructure() async throws {
        let gameCollection = try await GamePassCatalog.fetchGameCollection(
            for: GamePassCatalog.kGamePassConsoleIdentifier, language: "en-us", market: "US")

        // Test that the response structure is what we expect
        XCTAssertFalse(gameCollection.games.isEmpty, "Should have games")

        // Test game ID format (assuming they're GUIDs)
        for gameId in gameCollection.games {
            XCTAssertTrue(isValidMicrosoftProductId(gameId), "Game ID should be valid GUID: \(gameId)")
        }

        // Test header if present
        if let header = gameCollection.header {
            XCTAssertFalse(header.title.isEmpty, "Header title should not be empty")
            XCTAssertFalse(header.siglId.isEmpty, "Header SIGL ID should not be empty")
            XCTAssertTrue(isValidURL(header.imageUrl), "Header image URL should be valid")
        }
    }

    func testProductInformationResponseStructure() async throws {
        let gameCollection = try await GamePassCatalog.fetchGameCollection(
            for: GamePassCatalog.kGamePassConsoleIdentifier, language: "en-us", market: "US")

        let testGameIds = Array(gameCollection.games.prefix(3))
        let games = try await GamePassCatalog.fetchProductInformation(
            gameIds: testGameIds, languages: ["en-us"], market: "US")

        for game in games {
            XCTAssertFalse(game.title.isEmpty, "Game title should not be empty")
            // Description can be empty, but should not be nil
            XCTAssertNotNil(game.description, "Game description should not be nil")
        }
    }

    private func isValidMicrosoftProductId(_ string: String) -> Bool {
        // Microsoft Store product IDs are typically 12 characters
        // containing uppercase letters and numbers
        let productIdPattern = "^[A-Z0-9]{12}$"
        return string.range(of: productIdPattern, options: .regularExpression) != nil
    }

    private func isValidURL(_ url: URL) -> Bool { return url.scheme == "http" || url.scheme == "https" }

    func testAllKnownCatalogIdentifiers() async throws {
        let identifiers = [
            ("Console", GamePassCatalog.kGamePassConsoleIdentifier), ("PC", GamePassCatalog.kGamePassPcIdentifier),
            ("Standard", GamePassCatalog.kGamePassStandardIdentifier),
            ("Core", GamePassCatalog.kGamePassCoreIdentifier),
            ("Console Most Popular", GamePassCatalog.kConsoleMostPopularIdentifier),
            ("PC Most Popular", GamePassCatalog.kPcMostPopularIdentifier),
            ("Game Pass Standard Most Popular", GamePassCatalog.kGamePassStandardMostPopularIdentifier),
            ("Game Pass Core Most Popular", GamePassCatalog.kGamePassCoreMostPopularIdentifier),
            ("Cloud Most Popular", GamePassCatalog.kCloudMostPopularIdentifier),
            ("Console Recently Added", GamePassCatalog.kConsoleRecentlyAddedIdentifier),
            ("Console Coming Soon", GamePassCatalog.kConsoleComingToIdentifier),
            ("Console Leaving Soon", GamePassCatalog.kConsoleLeavingSoonIdentifier),
            ("PC Recently Added", GamePassCatalog.kPcRecentlyAddedIdentifier),
            ("PC Coming Soon", GamePassCatalog.kPcComingToIdentifier),
            ("Game Pass Standard Leaving Soon", GamePassCatalog.kGamePassStandardLeavingSoonIdentifier),
            ("Game Pass Standard Recently Added", GamePassCatalog.kGamePassStandardRecentlyAddedIdentifier),
            ("Game Pass Standard Coming Soon", GamePassCatalog.kGamePassStandardComingToIdentifier),
            ("Game Pass Standard Leaving Soon", GamePassCatalog.kGamePassStandardLeavingSoonIdentifier),
        ]

        for (name, identifier) in identifiers {
            do {
                let gameCollection = try await GamePassCatalog.fetchGameCollection(
                    for: identifier, language: "en-us", market: "US")

                // Some collections might be empty (like "leaving soon"), that's OK
                XCTAssertNotNil(gameCollection, "\(name) collection should not be nil")
                print("✅ \(name): \(gameCollection.games.count) games")

            } catch { XCTFail("Failed to fetch \(name) collection: \(error)") }
        }
    }

    func testDifferentMarketsAndLanguages() async throws {
        let testCases = [("en-us", "US"), ("en-gb", "GB"), ("de-de", "DE"), ("fr-fr", "FR")]

        for (language, market) in testCases {
            do {
                let gameCollection = try await GamePassCatalog.fetchGameCollection(
                    for: GamePassCatalog.kGamePassConsoleIdentifier, language: language, market: market)

                XCTAssertNotNil(gameCollection, "Should work for \(language)/\(market)")
                print("✅ \(language)/\(market): \(gameCollection.games.count) games")

            } catch {
                // Log but don't fail - some markets might not be supported
                print("⚠️  \(language)/\(market) failed: \(error)")
            }
        }
    }

    func testResponseTime() async throws {
        let startTime = Date()

        _ = try await GamePassCatalog.fetchGameCollection(
            for: GamePassCatalog.kGamePassConsoleIdentifier, language: "en-us", market: "US")

        let responseTime = Date().timeIntervalSince(startTime)

        // API should respond within reasonable time (adjust as needed)
        XCTAssertLessThan(responseTime, 10.0, "API should respond within 10 seconds")
        print("API response time: \(responseTime) seconds")
    }

    func testConcurrentRequests() async throws {
        let identifiers = [
            GamePassCatalog.kGamePassConsoleIdentifier, GamePassCatalog.kGamePassPcIdentifier,
            GamePassCatalog.kConsoleMostPopularIdentifier,
        ]

        // Test that we can make concurrent requests without issues
        try await withThrowingTaskGroup(of: GameCollection.self) { group in
            for identifier in identifiers {
                group.addTask {
                    try await GamePassCatalog.fetchGameCollection(for: identifier, language: "en-us", market: "US")
                }
            }

            var collections: [GameCollection] = []
            for try await collection in group { collections.append(collection) }

            XCTAssertEqual(collections.count, identifiers.count, "All concurrent requests should succeed")
        }
    }

    func testGameCollectionMinimumFields() async throws {
        let gameCollection = try await GamePassCatalog.fetchGameCollection(
            for: GamePassCatalog.kGamePassConsoleIdentifier, language: "en-us", market: "US")

        // Test minimum expected data
        XCTAssertGreaterThan(gameCollection.games.count, 50, "GamePass should have at least 50 games")

        // Test that we get some popular games (this will break if they remove major titles)
        let testGames = Array(gameCollection.games)
        let games = try await GamePassCatalog.fetchProductInformation(
            gameIds: testGames, languages: ["en-us"], market: "US")

        // Should have some well-known titles - adjust this list based on stable GamePass games
        let titles = games.map { $0.title.lowercased() }
        let hasPopularContent = titles.contains { title in
            title.contains("minecraft") || title.contains("forza") || title.contains("halo") || title.contains("gears")
        }

        XCTAssertTrue(hasPopularContent, "Should contain some Microsoft first-party games")
    }

    func testEndpointsAreWorking() async throws {
        // Test with a known working identifier
        let catalogURL = "https://catalog.gamepass.com/sigls/v2"
        let catalogRequest = URLRequest(
            url: URL(string: "\(catalogURL)?id=\(GamePassCatalog.kGamePassConsoleIdentifier)&language=en-us&market=US")!
        )
        let (_, catalogResponse) = try await URLSession.shared.data(for: catalogRequest)

        if let httpResponse = catalogResponse as? HTTPURLResponse {
            XCTAssertEqual(
                httpResponse.statusCode, 200,
                "Catalog API should return 200 for valid request (got \(httpResponse.statusCode))")
        }

        // First get some real game IDs
        let gameCollection = try await GamePassCatalog.fetchGameCollection(
            for: GamePassCatalog.kGamePassConsoleIdentifier, language: "en-us", market: "US")

        // Test product API with real game IDs
        let testGameIds = Array(gameCollection.games.prefix(3))
        let productURL = "https://displaycatalog.mp.microsoft.com/v7.0/products"
        let productRequest = URLRequest(
            url: URL(string: "\(productURL)?bigIds=\(testGameIds.joined(separator: ","))&languages=en-us&market=US")!)
        let (_, productResponse) = try await URLSession.shared.data(for: productRequest)

        if let httpResponse = productResponse as? HTTPURLResponse {
            XCTAssertEqual(
                httpResponse.statusCode, 200,
                "Product API should return 200 for valid request (got \(httpResponse.statusCode))")
        }
    }

}
