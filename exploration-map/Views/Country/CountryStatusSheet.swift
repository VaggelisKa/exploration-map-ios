//
//  CountryStatusSheet.swift
//  exploration-map
//

import SwiftUI

struct CountryStatusSheet: View {
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
                    Button {
                        store.updateStatus(pendingStatus, for: selection.id)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.regularMaterial, for: .navigationBar)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
