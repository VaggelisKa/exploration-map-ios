//
//  MapScreen.swift
//  exploration-map
//

import SwiftUI

struct MapScreen: View {
    var store: CountryStore
    var goalStore: GoalStore
    var settingsStore: SettingsStore
    @State private var selectedCountry: CountrySelection?
    @State private var showingWantToVisitList = false
    @State private var showingGoalCreation = false
    @State private var isStatsExpanded = UserDefaults.standard.bool(forKey: statsExpandedKey)
    @State private var showingShareFormatDialog = false
    @State private var isGeneratingShare = false
    @State private var showingSettings = false

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

                    HStack(spacing: 12) {
                        GlassEffectContainer {
                            Button {
                                showingSettings = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.subheadline.weight(.medium))
                                    Text("Settings")
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        GlassEffectContainer {
                            Button {
                                showingShareFormatDialog = true
                            } label: {
                                HStack(spacing: 6) {
                                    if isGeneratingShare {
                                        ProgressView()
                                            .scaleEffect(0.85)
                                    } else {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.subheadline.weight(.medium))
                                    }
                                    Text("Share map")
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(isGeneratingShare)
                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        GlassEffectContainer {
                            Button {
                                showingGoalCreation = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "target")
                                        .font(.subheadline.weight(.medium))
                                    Text("Goal")
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
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
        .confirmationDialog("Share map", isPresented: $showingShareFormatDialog, titleVisibility: .visible) {
            Button("Screenshot") { shareAsScreenshot() }
            Button("PDF") { shareAsPDF() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose format to share")
        }
        .sheet(item: $selectedCountry) { selection in
            CountryStatusSheet(selection: selection, store: store)
        }
        .sheet(isPresented: $showingWantToVisitList) {
            WantToVisitListView(store: store)
        }
        .sheet(isPresented: $showingGoalCreation) {
            GoalCreationSheet(store: store, goalStore: goalStore)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(settingsStore: settingsStore)
        }
        .environment(store)
        .onAppear {
            store.onDataChanged = { writeWidgetGoalsSnapshot(countryStore: store, goalStore: goalStore) }
            writeWidgetGoalsSnapshot(countryStore: store, goalStore: goalStore)
        }
    }

    private func shareAsScreenshot() {
        isGeneratingShare = true
        Task { @MainActor in
            let image = await MapShareImageGenerator.generate(store: store)
            isGeneratingShare = false
            if let image {
                SharePresenter.present(activityItems: [image]) { }
            }
        }
    }

    private func shareAsPDF() {
        isGeneratingShare = true
        Task { @MainActor in
            let pdfURL = await MapShareImageGenerator.generatePDF(store: store)
            isGeneratingShare = false
            if let pdfURL {
                SharePresenter.present(activityItems: [pdfURL]) {
                    try? FileManager.default.removeItem(at: pdfURL)
                }
            }
        }
    }
}

#Preview {
    MapScreen(store: CountryStore(), goalStore: GoalStore(), settingsStore: SettingsStore())
}
