import SwiftUI

struct CountryDescriptionSheet: View {
    let selection: CountrySelection
    var store: CountryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDetent: PresentationDetent = .large
    @State private var aiInsights: TravelInsights?
    @State private var isLoadingInsights = false
    @State private var insightsError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    if TravelInsightsService.isAvailable {
                        travelInsightsSection
                    }

                    if let desc = CountryDescriptionsLoader.description(for: selection.id) {
                        descriptionSection(title: "Overview", text: desc.overview)
                        descriptionSection(title: "Known for", text: desc.knownFor)
                        descriptionSection(title: "Quick history", text: desc.quickHistory)
                    } else {
                        descriptionSection(
                            title: "Overview",
                            text: "A short overview of this destination will appear here. You'll find key facts, geography, and a brief introduction to the country."
                        )
                        descriptionSection(
                            title: "Known for",
                            text: "Highlights and what this place is known for will be shown here."
                        )
                        descriptionSection(
                            title: "Quick history",
                            text: "A brief history will be available in a future update."
                        )
                    }

                    Spacer(minLength: 32)
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Text(store.flagEmoji(for: selection.id))
                            .font(.title2)
                        Text(selection.name)
                            .font(.headline)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.regularMaterial, for: .navigationBar)
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .onAppear {
            if TravelInsightsService.isAvailable {
                Task { await loadInsights() }
            }
        }
    }

    @MainActor
    private func loadInsights() async {
        if let cached = TravelInsightsService.cachedInsights(for: selection.id) {
            aiInsights = cached
            insightsError = nil
            return
        }
        isLoadingInsights = true
        insightsError = nil
        defer { isLoadingInsights = false }
        do {
            let insights = try await TravelInsightsService.generateInsights(for: selection.name)
            TravelInsightsService.saveInsights(insights, for: selection.id)
            aiInsights = insights
        } catch {
            insightsError = error.localizedDescription
        }
    }

    @ViewBuilder
    private var travelInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Travel insights")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if isLoadingInsights {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Getting travel tips…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if let error = insightsError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Try again") {
                        Task { await loadInsights() }
                    }
                    .font(.subheadline.weight(.medium))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if let insights = aiInsights {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        InsightCard(
                            title: "Best time to visit",
                            systemImage: "calendar.badge.clock",
                            text: insights.bestTimeToVisit
                        )
                        InsightCard(
                            title: "Getting there",
                            systemImage: "airplane",
                            text: insights.gettingThere
                        )
                        InsightCard(
                            title: "What to know",
                            systemImage: "newspaper",
                            text: insights.whatToKnow
                        )
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            Text(store.flagEmoji(for: selection.id))
                .font(.system(size: 48))
            VStack(alignment: .leading, spacing: 4) {
                Text(selection.name)
                    .font(.title2.weight(.semibold))
                if let continent = store.countryContinents[selection.id], !continent.isEmpty {
                    Text(continent)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func descriptionSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct InsightCard: View {
    let title: String
    let systemImage: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 260, alignment: .topLeading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    CountryDescriptionSheet(
        selection: CountrySelection(id: "USA", name: "United States"),
        store: CountryStore()
    )
}
