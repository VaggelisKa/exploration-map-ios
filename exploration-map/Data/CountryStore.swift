import Foundation
import MapKit
import Observation
import SwiftUI

enum CountryStatus: String, Codable, CaseIterable, Identifiable {
    case none
    case visited
    case wantToVisit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "Not set"
        case .visited:
            return "Visited or lived"
        case .wantToVisit:
            return "Want to visit"
        }
    }

    var uiColor: UIColor {
        switch self {
        case .none:
            return UIColor.systemGray
        case .visited:
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
    private(set) var countryCodes: [String: String] = [:]
    private(set) var countryContinents: [String: String] = [:]
    private(set) var revision: Int = 0
    var statuses: [String: CountryStatus] = [:]
    var wantToVisitOrder: [String] = []

    private let defaultsKey = "CountryStatusById"
    private let wantToVisitOrderKey = "WantToVisitOrder"

    var onDataChanged: (() -> Void)?

    init() {
        loadGeoJSON()
        loadStatuses()
        loadWantToVisitOrder()
        writeWidgetStatsSnapshot(from: self)
    }

    var totalCountries: Int {
        countryNames.count
    }

    var visitedCount: Int {
        statuses.values.filter { $0 == .visited }.count
    }

    var wantToVisitCount: Int {
        statuses.values.filter { $0 == .wantToVisit }.count
    }

    var wantToVisitCountryIds: [String] {
        let wantIds = Set(statuses.filter { $0.value == .wantToVisit }.map(\.key))
        let ordered = wantToVisitOrder.filter { wantIds.contains($0) }
        let unordered = wantIds.subtracting(ordered).sorted { displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending }
        return ordered + unordered
    }

    var visitedPercentage: Double {
        guard totalCountries > 0 else { return 0 }
        return Double(visitedCount) / Double(totalCountries)
    }

    var continentStats: [ContinentStat] {
        var byContinent: [String: (total: Int, visited: Int)] = [:]
        for (countryId, continent) in countryContinents {
            let c = continent.isEmpty ? "Other" : continent
            let current = byContinent[c] ?? (0, 0)
            let isVisited = statuses[countryId] == .visited
            byContinent[c] = (current.total + 1, current.visited + (isVisited ? 1 : 0))
        }
        return byContinent
            .map { ContinentStat(id: $0.key, name: $0.key, total: $0.value.total, visitedOrLived: $0.value.visited) }
            .filter { $0.visitedOrLived > 0 }
            .sorted { $0.percentage > $1.percentage }
    }

    func displayName(for countryId: String) -> String {
        countryNames[countryId] ?? countryId
    }

    func flagEmoji(for countryId: String) -> String {
        let code = countryCodes[countryId] ?? countryCodes[countryId.uppercased()]
            ?? Self.alpha3ToAlpha2[countryId] ?? Self.alpha3ToAlpha2[countryId.uppercased()]
        guard let code = code, code.count == 2 else { return "" }
        let base: UInt32 = 0x1F1E6 - 0x41
        return code.uppercased().unicodeScalars.compactMap { scalar in
            guard scalar.value >= 65, scalar.value <= 90,
                  let u = Unicode.Scalar(base + scalar.value) else { return nil }
            return Character(u)
        }.map(String.init).joined()
    }

    private static let alpha3ToAlpha2: [String: String] = [
        "FRA": "FR", "NOR": "NO", "KOS": "XK"
    ]

    func status(for countryId: String) -> CountryStatus {
        statuses[countryId] ?? .none
    }

    func updateStatus(_ status: CountryStatus, for countryId: String) {
        if status == .none {
            statuses.removeValue(forKey: countryId)
            wantToVisitOrder.removeAll { $0 == countryId }
        } else {
            statuses[countryId] = status
            if status == .wantToVisit, !wantToVisitOrder.contains(countryId) {
                wantToVisitOrder.append(countryId)
            } else if status != .wantToVisit {
                wantToVisitOrder.removeAll { $0 == countryId }
            }
        }
        saveStatuses()
        saveWantToVisitOrder()
        bumpRevision()
    }

    func updateWantToVisitOrder(_ ids: [String]) {
        wantToVisitOrder = ids
        saveWantToVisitOrder()
        bumpRevision()
    }

    func fillColor(for status: CountryStatus) -> UIColor {
        switch status {
        case .none:
            return UIColor.systemGray.withAlphaComponent(0.08)
        case .visited:
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
                if let iso2 = extractIso2(from: props) {
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

    private func loadWantToVisitOrder() {
        guard let data = UserDefaults.standard.data(forKey: wantToVisitOrderKey),
              let order = try? JSONDecoder().decode([String].self, from: data) else { return }
        wantToVisitOrder = order.filter { statuses[$0] == .wantToVisit }
    }

    private func saveWantToVisitOrder() {
        guard let data = try? JSONEncoder().encode(wantToVisitOrder) else { return }
        UserDefaults.standard.set(data, forKey: wantToVisitOrderKey)
        writeWidgetStatsSnapshot(from: self)
        onDataChanged?()
    }

    private func loadStatuses() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        // Decode as raw strings so we can migrate old "lived" to "visited"
        guard let raw = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        var decoded: [String: CountryStatus] = [:]
        for (id, rawValue) in raw {
            let status: CountryStatus = rawValue == "lived" ? .visited : (CountryStatus(rawValue: rawValue) ?? .none)
            if status != .none || rawValue == "lived" {
                decoded[id] = status
            }
        }
        if !decoded.isEmpty {
            statuses = decoded
            bumpRevision()
        }
    }

    private func saveStatuses() {
        guard let data = try? JSONEncoder().encode(statuses) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
        writeWidgetStatsSnapshot(from: self)
        onDataChanged?()
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

    private func extractIso2(from properties: [String: String]) -> String? {
        let raw = properties["ISO_A2"] ?? properties["iso_a2"] ?? properties["ISO_A2_EH"]
        guard let raw = raw, raw != "-99", raw.count == 2 else { return nil }
        return raw
    }

    private func extractId(from properties: [String: String], fallbackName: String) -> String {
        func validId(_ id: String?) -> String? {
            guard let id = id, id != "-99", id.count == 3 else { return nil }
            return id
        }
        if let id = validId(properties["ISO_A3"]) ?? validId(properties["iso_a3"]) { return id }
        if let id = validId(properties["ADM0_A3"]) { return id }
        if let id = validId(properties["SOV_A3"]) { return id }
        if let id = validId(properties["GU_A3"]) { return id }
        if let id = validId(properties["SU_A3"]) { return id }
        if let id = validId(properties["BRK_A3"]) { return id }
        if let id = properties["id"], !id.isEmpty { return id }
        return fallbackName
    }
}
