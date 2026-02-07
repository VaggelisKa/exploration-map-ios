//
//  CountryDescriptions.swift
//  exploration-map
//

import Foundation

struct CountryDescription: Codable {
    let overview: String
    let knownFor: String
    let quickHistory: String
}

enum CountryDescriptionsLoader {
    private static let cache: [String: CountryDescription] = loadFromBundle()

    static func description(for countryId: String) -> CountryDescription? {
        cache[countryId]
    }

    private static func loadFromBundle() -> [String: CountryDescription] {
        guard let url = Bundle.main.url(forResource: "country_descriptions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: CountryDescription].self, from: data) else {
            return [:]
        }
        return decoded
    }
}
