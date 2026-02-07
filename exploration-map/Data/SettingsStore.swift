//
//  SettingsStore.swift
//  exploration-map
//

import Foundation
import Observation
import SwiftUI

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }

    var iconName: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }

    var resolvedColorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

private let themeDefaultsKey = "ExplorationMapTheme"

@Observable
@MainActor
final class SettingsStore {
    var theme: AppTheme {
        didSet { saveTheme() }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: themeDefaultsKey),
           let decoded = AppTheme(rawValue: raw) {
            self.theme = decoded
        } else {
            self.theme = .system
        }
    }

    private func saveTheme() {
        UserDefaults.standard.set(theme.rawValue, forKey: themeDefaultsKey)
    }
}
