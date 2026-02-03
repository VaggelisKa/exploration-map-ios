import SwiftUI

let statsExpandedKey = "StatsExpanded"

struct StatsView: View {
    var store: CountryStore
    @Binding var isExpanded: Bool

    init(store: CountryStore, isExpanded: Binding<Bool>) {
        self.store = store
        _isExpanded = isExpanded
    }

    var body: some View {
        GlassEffectContainer {
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
                    StatDivider()
                    StatRow(title: "Visited or lived", value: "\(store.visitedCount)")
                    StatDivider()
                    StatRow(
                        title: "World visited or lived",
                        value: String(format: "%.1f%%", store.visitedPercentage * 100.0)
                    )
                    ForEach(store.continentStats) { stat in
                        StatDivider()
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
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .onChange(of: isExpanded) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: statsExpandedKey)
        }
    }
}

private struct StatDivider: View {
    var body: some View {
        Rectangle()
            .fill(.primary.opacity(0.5))
            .frame(height: 1)
    }
}

private struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.75))
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    StatsView(store: CountryStore(), isExpanded: .constant(true))
}
