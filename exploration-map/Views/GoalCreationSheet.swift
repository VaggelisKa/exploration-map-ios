//
//  GoalCreationSheet.swift
//  exploration-map
//

import SwiftUI

struct GoalCreationSheet: View {
    @Environment(\.dismiss) private var dismiss
    var store: CountryStore
    var goalStore: GoalStore

    @State private var goalType: GoalType = .countries
    @State private var countriesTarget: Int = 50
    @State private var percentageTarget: Double = 25
    @State private var selectedCountryIds: [String] = []
    @State private var targetDate: Date?
    @State private var customTitle: String = ""
    @State private var showingCountryPicker = false
    enum FocusableField: Hashable {
        case goalName
    }
    @FocusState private var focusedField: FocusableField?
    @State private var selectedTab: GoalSheetTab = .newGoal
    @State private var showingSavedToast = false
    @State private var keyboardDismissOverlayActive = false

    enum GoalSheetTab: String, CaseIterable {
        case newGoal = "New goal"
        case myGoals = "My goals"
    }

    enum GoalType: String, CaseIterable {
        case countries = "Visit N countries"
        case percentage = "Reach N% of world"
        case specificCountries = "Specific countries"
    }

    private var canSave: Bool {
        switch goalType {
        case .countries: return countriesTarget > 0 && countriesTarget <= store.totalCountries
        case .percentage: return percentageTarget > 0 && percentageTarget <= 100
        case .specificCountries: return !selectedCountryIds.isEmpty
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(GoalSheetTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch selectedTab {
                case .newGoal:
                    Form {
                        newGoalContent
                    }
                    .scrollDismissesKeyboard(.interactively)
                case .myGoals:
                    myGoalsView
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }
                if selectedTab == .newGoal {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveAndDismiss() }
                            .disabled(!canSave)
                    }
                }
            }
            .overlay(keyboardDismissOverlay)
            .overlay(savedToast)
            .onChange(of: focusedField) { _, newValue in
                if newValue == .goalName {
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.3))
                        keyboardDismissOverlayActive = true
                    }
                } else {
                    keyboardDismissOverlayActive = false
                }
            }
            .sheet(isPresented: $showingCountryPicker) {
                CountryGoalPickerSheet(store: store, selectedIds: $selectedCountryIds)
            }
        }
    }

    @ViewBuilder
    private var newGoalContent: some View {
        Group {
            Section {
                TextField("Goal name (optional)", text: $customTitle)
                    .focused($focusedField, equals: .goalName)
            }

            Section {
                Picker("Goal type", selection: $goalType) {
                    ForEach(GoalType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                switch goalType {
                    case .countries:
                        HStack {
                            Text("Target")
                            Spacer()
                            TextField("Countries", value: $countriesTarget, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        Text("You've visited \(store.visitedCount) of \(store.totalCountries) countries.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .percentage:
                        HStack {
                            Text("Target")
                            Spacer()
                            TextField("%", value: $percentageTarget, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        Text("You're at \(String(format: "%.1f", store.visitedPercentage * 100))% of the world.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .specificCountries:
                        Button {
                            showingCountryPicker = true
                        } label: {
                            HStack {
                                Text("Countries")
                                Spacer()
                                Text(selectedCountryIds.isEmpty ? "Add countries" : "\(selectedCountryIds.count) selected")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if !selectedCountryIds.isEmpty {
                            ForEach(selectedCountryIds, id: \.self) { id in
                                HStack {
                                    Text(store.flagEmoji(for: id))
                                    Text(store.displayName(for: id))
                                    Spacer()
                                    Button(role: .destructive) {
                                        selectedCountryIds.removeAll { $0 == id }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

            Section("By date (optional)") {
                Toggle("Set target date", isOn: Binding(
                    get: { targetDate != nil },
                    set: { if $0 { targetDate = targetDate ?? defaultTargetDate() } else { targetDate = nil } }
                ))
                if targetDate != nil {
                    DatePicker("By", selection: Binding(get: { targetDate ?? defaultTargetDate() }, set: { targetDate = $0 }), in: Date()..., displayedComponents: .date)
                }
            }
        }
    }

    @ViewBuilder
    private var myGoalsView: some View {
        if goalStore.goals.isEmpty {
            ContentUnavailableView {
                Label("No goals yet", systemImage: "target")
            } description: {
                Text("Switch to \"New goal\" to add one.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(goalStore.goals) { goal in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(goal.title ?? goalDisplayTitle(goal))
                                .font(.subheadline.weight(.medium))
                            Text(goal.kind.label + (goal.targetDate.map { " · by \(Self.dateFormatter.string(from: $0))" } ?? ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        progressLabel(goal: goal)
                    }
                }
                .onDelete { indexSet in
                    let toRemove = indexSet.compactMap { i in
                        i < goalStore.goals.count ? goalStore.goals[i] : nil
                    }
                    for goal in toRemove { goalStore.remove(goal) }
                    writeWidgetGoalsSnapshot(countryStore: store, goalStore: goalStore)
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    @ViewBuilder
    private var keyboardDismissOverlay: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture { focusedField = nil }
            .ignoresSafeArea()
            .allowsHitTesting(keyboardDismissOverlayActive)
    }

    @ViewBuilder
    private var savedToast: some View {
        if showingSavedToast {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                Text("Goal saved")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.75), in: Capsule())
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .animation(.easeOut(duration: 0.25), value: showingSavedToast)
        }
    }

    private func defaultTargetDate() -> Date {
        var c = Calendar.current.dateComponents([.year], from: Date())
        c.year = (c.year ?? 2030) + 5
        return Calendar.current.date(from: c) ?? Calendar.current.date(byAdding: .year, value: 5, to: Date())!
    }

    private func goalDisplayTitle(_ goal: Goal) -> String {
        switch goal.kind {
        case .countries, .percentage:
            return goal.kind.label
        case .specificCountries(let ids):
            let names = ids.map { store.displayName(for: $0) }
            let byDate = goal.targetDate.map { " by \(Self.dateFormatter.string(from: $0))" } ?? ""
            return names.joined(separator: ", ") + byDate
        }
    }

    private func progressLabel(goal: Goal) -> some View {
        Group {
            switch goal.kind {
            case .countries(let target):
                Text("\(store.visitedCount)/\(target)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(store.visitedCount >= target ? .green : .secondary)
            case .percentage(let target):
                let current = store.visitedPercentage * 100
                Text("\(String(format: "%.1f", current))%/\(String(format: "%.1f", target))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(current >= target ? .green : .secondary)
            case .specificCountries(let ids):
                let visited = ids.filter { store.status(for: $0) == .visited }.count
                Text("\(visited)/\(ids.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(visited >= ids.count ? .green : .secondary)
            }
        }
    }

    private func saveAndDismiss() {
        let kind: GoalKind
        switch goalType {
        case .countries: kind = .countries(countriesTarget)
        case .percentage: kind = .percentage(percentageTarget)
        case .specificCountries: kind = .specificCountries(selectedCountryIds)
        }
        let title = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        goalStore.add(Goal(kind: kind, title: title.isEmpty ? nil : title, targetDate: targetDate))
        writeWidgetGoalsSnapshot(countryStore: store, goalStore: goalStore)
        resetForm()
        showingSavedToast = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            showingSavedToast = false
            dismiss()
        }
    }

    private func resetForm() {
        goalType = .countries
        countriesTarget = 50
        percentageTarget = 25
        selectedCountryIds = []
        targetDate = nil
        customTitle = ""
        focusedField = nil
    }

}

// MARK: - Country picker for specific-countries goal

private struct CountryRow: Identifiable {
    let id: String
    let name: String
}

private struct CountryPickerRowView: View {
    var store: CountryStore
    var row: CountryRow
    var isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(store.flagEmoji(for: row.id))
                Text(verbatim: row.name)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }
}

private struct CountryGoalPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var store: CountryStore
    @Binding var selectedIds: [String]

    @State private var searchText = ""

    private var sortedCountries: [CountryRow] {
        let pairs = store.countryNames.map { CountryRow(id: $0.key, name: $0.value) }
        let sorted = pairs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if searchText.isEmpty { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            countryList
                .searchable(text: $searchText, prompt: "Search countries")
                .navigationTitle("Select countries")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var countryList: some View {
        List {
            ForEach(sortedCountries, id: \CountryRow.id) { row in
                CountryPickerRowView(
                    store: store,
                    row: row,
                    isSelected: selectedIds.contains(row.id)
                ) {
                    if selectedIds.contains(row.id) {
                        selectedIds.removeAll { $0 == row.id }
                    } else {
                        selectedIds.append(row.id)
                    }
                }
            }
        }
    }
}

#Preview {
    GoalCreationSheet(store: CountryStore(), goalStore: GoalStore())
}
