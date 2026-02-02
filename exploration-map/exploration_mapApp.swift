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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
