//
//  WidgetStatsSnapshot.swift
//  exploration-map
//
//  Snapshot struct and writer for the stats widget. The widget extension
//  uses the same struct and key to read from the shared App Group.
//

import Foundation
import WidgetKit

/// App Group suite name; must match the capability in app and widget entitlements.
let widgetStatsAppGroupSuiteName = "group.www.exploration-map"

/// UserDefaults key for the encoded snapshot.
let widgetStatsSnapshotKey = "WidgetStatsSnapshot"

/// Widget kind string for reloadTimelines(ofKind:).
let explorationMapWidgetKind = "ExplorationMapStatsWidget"

/// Codable snapshot of stats written by the app and read by the widget.
struct WidgetStatsSnapshot: Codable {
    var totalCountries: Int
    var visitedCount: Int
    var wantToVisitCount: Int
    var visitedPercentage: Double
    /// Continent name and percentage (0...1), same order as StatsView.
    var continentStats: [ContinentStatEntry]

    struct ContinentStatEntry: Codable {
        var name: String
        var percentage: Double
    }

    /// Placeholder when no snapshot is available.
    static var placeholder: WidgetStatsSnapshot {
        WidgetStatsSnapshot(
            totalCountries: 0,
            visitedCount: 0,
            wantToVisitCount: 0,
            visitedPercentage: 0,
            continentStats: []
        )
    }
}

/// Writes the current stats from the given store to the App Group UserDefaults.
/// Call from the main app whenever statuses or want-to-visit order change, and after init.
func writeWidgetStatsSnapshot(from store: CountryStore) {
    let snapshot = WidgetStatsSnapshot(
        totalCountries: store.totalCountries,
        visitedCount: store.visitedCount,
        wantToVisitCount: store.wantToVisitCount,
        visitedPercentage: store.visitedPercentage,
        continentStats: store.continentStats.map { stat in
            WidgetStatsSnapshot.ContinentStatEntry(name: stat.name, percentage: stat.percentage)
        }
    )
    guard let data = try? JSONEncoder().encode(snapshot) else { return }
    UserDefaults(suiteName: widgetStatsAppGroupSuiteName)?.set(data, forKey: widgetStatsSnapshotKey)

    #if canImport(WidgetKit)
    WidgetCenter.shared.reloadTimelines(ofKind: explorationMapWidgetKind)
    #endif
}
