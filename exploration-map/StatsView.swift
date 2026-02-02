import SwiftUI

private let statsExpandedKey = "StatsExpanded"

struct StatsView: View {
    var store: CountryStore
    @State private var isExpanded: Bool
    @State private var hasLoadedFromStorage = false

    init(store: CountryStore) {
        self.store = store
        _isExpanded = State(initialValue: UserDefaults.standard.bool(forKey: statsExpandedKey))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Stats")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer(minLength: 8)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    StatRow(title: "Countries", value: "\(store.totalCountries)")
                    Divider()
                    StatRow(title: "Visited", value: "\(store.visitedCount)")
                    Divider()
                    StatRow(title: "Lived", value: "\(store.livedCount)")
                    Divider()
                    StatRow(title: "Want to visit", value: "\(store.wantToVisitCount)")
                    Divider()
                    StatRow(
                        title: "World visited",
                        value: String(format: "%.1f%%", store.visitedPercentage * 100.0)
                    )
                    ForEach(store.continentStats) { stat in
                        Divider()
                        StatRow(
                            title: stat.name,
                            value: String(format: "%.1f%%", stat.percentage * 100.0)
                        )
                    }
                }
                .padding(.top, 10)
                .padding(.vertical, 4)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onChange(of: isExpanded) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: statsExpandedKey)
        }
    }
}

private struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    StatsView(store: CountryStore())
}
