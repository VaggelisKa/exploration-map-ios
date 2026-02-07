import SwiftUI

struct WantToVisitListView: View {
    var store: CountryStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.editMode) private var editMode
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
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(editMode?.wrappedValue.isEditing == true)
                            .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        }
                        .onMove { source, destination in
                            var ids = store.wantToVisitCountryIds
                            ids.move(fromOffsets: source, toOffset: destination)
                            withAnimation(.default) {
                                store.updateWantToVisitOrder(ids)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Want to visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EditButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
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
            CountryDescriptionSheet(selection: selection, store: store)
        }
    }
}
