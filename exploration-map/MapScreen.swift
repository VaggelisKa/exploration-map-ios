//
//  MapScreen.swift
//  exploration-map
//
//  Created by Vaggelis Karavasileiadis on 2/2/26.
//

import SwiftUI

struct MapScreen: View {
    @Environment(CountryStore.self) private var store
    @State private var selectedCountry: CountrySelection?
    @State private var showingWantToVisitList = false
    @State private var isStatsExpanded = UserDefaults.standard.bool(forKey: statsExpandedKey)

    var body: some View {
        ZStack(alignment: .bottom) {
            CountryMapView(store: store, selectedCountry: $selectedCountry)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                StatsView(store: store, isExpanded: $isStatsExpanded)

                if isStatsExpanded {
                    GlassEffectContainer {
                        Button {
                            showingWantToVisitList = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "list.star")
                                    .font(.subheadline.weight(.medium))
                                Text("Want to visit")
                                    .font(.subheadline.weight(.medium))
                                Text("(\(store.wantToVisitCount))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isStatsExpanded)
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .sheet(item: $selectedCountry) { selection in
            CountryStatusSheet(selection: selection, store: store)
        }
        .sheet(isPresented: $showingWantToVisitList) {
            WantToVisitListView(store: store)
        }
    }
}

private struct CountryStatusSheet: View {
    let selection: CountrySelection
    var store: CountryStore
    @Environment(\.dismiss) private var dismiss
    @State private var pendingStatus: CountryStatus

    init(selection: CountrySelection, store: CountryStore) {
        self.selection = selection
        self.store = store
        _pendingStatus = State(initialValue: store.status(for: selection.id))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(CountryStatus.allCases) { status in
                    Button {
                        pendingStatus = status
                    } label: {
                        HStack {
                            Text(status.title)
                                .foregroundStyle(.primary)
                            Spacer()
                            if pendingStatus == status {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle([store.flagEmoji(for: selection.id), selection.name].filter { !$0.isEmpty }.joined(separator: " "))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        store.updateStatus(pendingStatus, for: selection.id)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.regularMaterial, for: .navigationBar)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct WantToVisitListView: View {
    var store: CountryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCountry: CountrySelection?

    var body: some View {
        NavigationStack {
            Group {
                if store.wantToVisitCountryIds.isEmpty {
                    ContentUnavailableView(
                        "No countries yet",
                        systemImage: "map",
                        description: Text("Tap a country on the map and choose \"Want to visit\" to add it here.")
                    )
                } else {
                    List {
                        ForEach(store.wantToVisitCountryIds, id: \.self) { countryId in
                            Button {
                                selectedCountry = CountrySelection(
                                    id: countryId,
                                    name: store.displayName(for: countryId)
                                )
                            } label: {
                                HStack(spacing: 12) {
                                    Text(store.flagEmoji(for: countryId))
                                        .font(.title2)
                                    Text(store.displayName(for: countryId))
                                        .foregroundStyle(.primary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Want to visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.regularMaterial, for: .navigationBar)
        }
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(item: $selectedCountry) { selection in
            CountryStatusSheet(selection: selection, store: store)
        }
    }
}

#Preview {
    MapScreen()
        .environment(CountryStore())
}
