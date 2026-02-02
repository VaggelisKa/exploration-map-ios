import Foundation
import MapKit
import Observation
import SwiftUI

enum CountryStatus: String, Codable, CaseIterable, Identifiable {
    case none
    case visited
    case lived
    case wantToVisit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "Not set"
        case .visited:
            return "Visited"
        case .lived:
            return "Lived"
        case .wantToVisit:
            return "Want to visit"
        }
    }

    var uiColor: UIColor {
        switch self {
        case .none:
            return UIColor.systemGray
        case .visited:
            return UIColor.systemGreen
        case .lived:
            return UIColor.systemBlue
        case .wantToVisit:
            return UIColor.systemOrange
        }
    }

    var color: Color {
        Color(uiColor)
    }
}

struct CountrySelection: Identifiable, Equatable {
    let id: String
    let name: String
}

struct ContinentStat: Identifiable {
    let id: String
    let name: String
    let total: Int
    let visitedOrLived: Int
    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(visitedOrLived) / Double(total)
    }
}

@Observable
@MainActor
final class CountryStore {
    private(set) var overlays: [MKPolygon] = []
    private(set) var countryNames: [String: String] = [:]
    /// ISO 3166-1 alpha-2 (e.g. "US") for flag emoji.
    private(set) var countryCodes: [String: String] = [:]
    /// Continent name per country (e.g. "Africa", "Europe").
    private(set) var countryContinents: [String: String] = [:]
    private(set) var revision: Int = 0
    var statuses: [String: CountryStatus] = [:]

    private let defaultsKey = "CountryStatusById"

    init() {
        loadGeoJSON()
        loadStatuses()
    }

    var totalCountries: Int {
        countryNames.count
    }

    var visitedCount: Int {
        statuses.values.filter { $0 == .visited }.count
    }

    var livedCount: Int {
        statuses.values.filter { $0 == .lived }.count
    }

    var wantToVisitCount: Int {
        statuses.values.filter { $0 == .wantToVisit }.count
    }

    var visitedOrLivedCount: Int {
        statuses.values.filter { $0 == .visited || $0 == .lived }.count
    }

    var visitedPercentage: Double {
        guard totalCountries > 0 else { return 0 }
        return Double(visitedOrLivedCount) / Double(totalCountries)
    }

    /// Per-continent stats (percentage visited) sorted by continent name.
    var continentStats: [ContinentStat] {
        var byContinent: [String: (total: Int, visited: Int)] = [:]
        for (countryId, continent) in countryContinents {
            let c = continent.isEmpty ? "Other" : continent
            let current = byContinent[c] ?? (0, 0)
            let isVisited = statuses[countryId] == .visited || statuses[countryId] == .lived
            byContinent[c] = (current.total + 1, current.visited + (isVisited ? 1 : 0))
        }
        return byContinent
            .map { ContinentStat(id: $0.key, name: $0.key, total: $0.value.total, visitedOrLived: $0.value.visited) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func displayName(for countryId: String) -> String {
        countryNames[countryId] ?? countryId
    }

    /// Returns the country's flag emoji (e.g. 🇺🇸) from its ISO alpha-2 code, or empty string.
    func flagEmoji(for countryId: String) -> String {
        guard let code = countryCodes[countryId] ?? countryCodes[countryId.uppercased()],
              code.count == 2 else { return "" }
        let base: UInt32 = 0x1F1E6 - 0x41
        return code.uppercased().unicodeScalars.compactMap { scalar in
            guard scalar.value >= 65, scalar.value <= 90,
                  let u = Unicode.Scalar(base + scalar.value) else { return nil }
            return Character(u)
        }.map(String.init).joined()
    }

    func status(for countryId: String) -> CountryStatus {
        statuses[countryId] ?? .none
    }

    func updateStatus(_ status: CountryStatus, for countryId: String) {
        if status == .none {
            statuses.removeValue(forKey: countryId)
        } else {
            statuses[countryId] = status
        }
        saveStatuses()
        bumpRevision()
    }

    func fillColor(for status: CountryStatus) -> UIColor {
        switch status {
        case .none:
            return UIColor.systemGray.withAlphaComponent(0.08)
        case .visited:
            return UIColor.systemGreen.withAlphaComponent(0.45)
        case .lived:
            return UIColor.systemBlue.withAlphaComponent(0.45)
        case .wantToVisit:
            return UIColor.systemOrange.withAlphaComponent(0.45)
        }
    }

    func strokeColor(for status: CountryStatus) -> UIColor {
        switch status {
        case .none:
            return UIColor.systemGray.withAlphaComponent(0.35)
        case .visited:
            return UIColor.systemGreen.withAlphaComponent(0.9)
        case .lived:
            return UIColor.systemBlue.withAlphaComponent(0.9)
        case .wantToVisit:
            return UIColor.systemOrange.withAlphaComponent(0.9)
        }
    }

    private func loadGeoJSON() {
        guard let url = Bundle.main.url(forResource: "countries", withExtension: "geojson") else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let objects = try MKGeoJSONDecoder().decode(data)
            var polygons: [MKPolygon] = []
            var names: [String: String] = [:]
            var codes: [String: String] = [:]
            var continents: [String: String] = [:]

            for case let feature as MKGeoJSONFeature in objects {
                let props = propertiesDictionary(from: feature.properties)
                let name = extractName(from: props)
                let id = extractId(from: props, fallbackName: name)

                if names[id] == nil {
                    names[id] = name
                }
                if let iso2 = props["ISO_A2"] ?? props["iso_a2"], iso2.count == 2 {
                    codes[id] = iso2
                }
                if let continent = props["CONTINENT"] ?? props["REGION_UN"], !continent.isEmpty {
                    continents[id] = continent
                }

                for geometry in feature.geometry {
                    appendPolygons(from: geometry, id: id, name: name, to: &polygons)
                }
            }

            overlays = polygons
            countryNames = names
            countryCodes = codes
            countryContinents = continents
            bumpRevision()
        } catch {
            // Keep the app running even if the GeoJSON fails to load.
        }
    }

    private func loadStatuses() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        if let decoded = try? JSONDecoder().decode([String: CountryStatus].self, from: data) {
            statuses = decoded
            bumpRevision()
        }
    }

    private func saveStatuses() {
        guard let data = try? JSONEncoder().encode(statuses) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func bumpRevision() {
        revision += 1
    }

    private func appendPolygons(from shape: MKShape, id: String, name: String, to polygons: inout [MKPolygon]) {
        if let polygon = shape as? MKPolygon {
            polygon.title = id
            polygon.subtitle = name
            polygons.append(polygon)
        } else if let multiPolygon = shape as? MKMultiPolygon {
            for polygon in multiPolygon.polygons {
                polygon.title = id
                polygon.subtitle = name
                polygons.append(polygon)
            }
        }
    }

    private func propertiesDictionary(from data: Data?) -> [String: String] {
        guard let data, let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }

        var result: [String: String] = [:]
        for (key, value) in jsonObject {
            if let string = value as? String {
                result[key] = string
            } else if let number = value as? NSNumber {
                result[key] = number.stringValue
            }
        }
        return result
    }

    private func extractName(from properties: [String: String]) -> String {
        if let name = properties["name"] { return name }
        if let name = properties["NAME"] { return name }
        if let name = properties["ADMIN"] { return name }
        if let name = properties["NAME_LONG"] { return name }
        return "Unknown"
    }

    private func extractId(from properties: [String: String], fallbackName: String) -> String {
        if let id = properties["ISO_A3"] { return id }
        if let id = properties["iso_a3"] { return id }
        if let id = properties["ADM0_A3"] { return id }
        if let id = properties["SOV_A3"] { return id }
        if let id = properties["GU_A3"] { return id }
        if let id = properties["SU_A3"] { return id }
        if let id = properties["BRK_A3"] { return id }
        if let id = properties["id"] { return id }
        return fallbackName
    }
}
