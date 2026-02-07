//
//  exploration_mapApp.swift
//  exploration-map
//
//  Created by Vaggelis Karavasileiadis on 2/2/26.
//

import SwiftUI

@main
struct exploration_mapApp: App {
    @State private var store = CountryStore()
    @State private var goalStore = GoalStore()
    @State private var settingsStore = SettingsStore()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                MapScreen(store: store, goalStore: goalStore, settingsStore: settingsStore)
                    .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .preferredColorScheme(settingsStore.theme.resolvedColorScheme)
            .animation(.easeInOut(duration: 0.5), value: showSplash)
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    showSplash = false
                }
            }
        }
    }
}
