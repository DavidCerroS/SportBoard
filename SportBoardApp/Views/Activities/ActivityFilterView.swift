//
//  ActivityFilterView.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import SwiftUI

struct ActivityFilterView: View {
    @Bindable var viewModel: ActivitiesViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // Tipo de deporte
                Section("Tipo de Deporte") {
                    Picker("Deporte", selection: $viewModel.selectedSportType) {
                        Text("Todos").tag(nil as String?)
                        
                        ForEach(viewModel.sportTypes, id: \.self) { sport in
                            Label(sport.sportDisplayName, systemImage: sport.sportIcon)
                                .tag(sport as String?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Rango de fechas
                Section("Rango de Fechas") {
                    DatePicker(
                        "Desde",
                        selection: Binding(
                            get: { viewModel.dateRangeStart ?? Date().daysAgo(365) },
                            set: { viewModel.dateRangeStart = $0 }
                        ),
                        displayedComponents: .date
                    )
                    
                    DatePicker(
                        "Hasta",
                        selection: Binding(
                            get: { viewModel.dateRangeEnd ?? Date() },
                            set: { viewModel.dateRangeEnd = $0 }
                        ),
                        displayedComponents: .date
                    )
                    
                    if viewModel.dateRangeStart != nil || viewModel.dateRangeEnd != nil {
                        Button("Quitar filtro de fechas") {
                            viewModel.dateRangeStart = nil
                            viewModel.dateRangeEnd = nil
                        }
                        .foregroundStyle(.red)
                    }
                }
                
                // Ordenamiento
                Section("Ordenar por") {
                    Picker("Orden", selection: $viewModel.sortOrder) {
                        ForEach(ActivitiesViewModel.SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Limpiar filtros
                if viewModel.hasActiveFilters {
                    Section {
                        Button(role: .destructive) {
                            viewModel.clearFilters()
                        } label: {
                            Label("Limpiar todos los filtros", systemImage: "xmark.circle")
                        }
                    }
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") {
                        viewModel.applyFilters()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Quick Filter Chips

struct QuickFilterChips: View {
    @Bindable var viewModel: ActivitiesViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Chip "Todos"
                FilterChip(
                    title: "Todos",
                    isSelected: viewModel.selectedSportType == nil,
                    color: Color.stravaOrange
                ) {
                    viewModel.selectedSportType = nil
                }
                
                // Chips por deporte
                ForEach(viewModel.sportTypes.prefix(5), id: \.self) { sport in
                    FilterChip(
                        title: sport.sportDisplayName,
                        icon: sport.sportIcon,
                        isSelected: viewModel.selectedSportType == sport,
                        color: Color.sportColor(for: sport)
                    ) {
                        if viewModel.selectedSportType == sport {
                            viewModel.selectedSportType = nil
                        } else {
                            viewModel.selectedSportType = sport
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ActivityFilterView(viewModel: ActivitiesViewModel())
}
