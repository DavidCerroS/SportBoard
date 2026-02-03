//
//  PostActivityReflectionView.swift
//  SportBoardApp
//
//  Reflexión post-entreno: sensación (1–5), ¿forcé de más?, ¿repetiría hoy?
//

import SwiftUI
import SwiftData

struct PostActivityReflectionView: View {
    let activity: Activity
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var feelingScore: Int = 3
    @State private var pushedTooHard: Bool = false
    @State private var wouldRepeatToday: Bool = true
    @State private var existingReflection: PostActivityReflection?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("¿Cómo te sentiste?")
                            .font(.subheadline)
                        HStack(spacing: 16) {
                            ForEach(1...5, id: \.self) { n in
                                Button {
                                    feelingScore = n
                                } label: {
                                    Text("\(n)")
                                        .frame(width: 44, height: 44)
                                        .background(feelingScore == n ? Color.stravaOrange.opacity(0.3) : Color(.secondarySystemBackground))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text("1 = muy mal, 5 = muy bien")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Sensación")
                }
                
                Section {
                    Toggle("¿Forcé de más?", isOn: $pushedTooHard)
                    Toggle("¿Repetiría este entreno hoy?", isOn: $wouldRepeatToday)
                } header: {
                    Text("Reflexión")
                }
            }
            .navigationTitle("Reflexión post-entreno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveReflection()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadExistingReflection()
            }
        }
    }
    
    private func loadExistingReflection() {
        let all = (try? modelContext.fetch(FetchDescriptor<PostActivityReflection>())) ?? []
        existingReflection = all.first { $0.activityId == activity.id }
        if let r = existingReflection {
            feelingScore = r.feelingScore
            pushedTooHard = r.pushedTooHard
            wouldRepeatToday = r.wouldRepeatToday
        }
    }
    
    private func saveReflection() {
        if let existing = existingReflection {
            existing.feelingScore = min(5, max(1, feelingScore))
            existing.pushedTooHard = pushedTooHard
            existing.wouldRepeatToday = wouldRepeatToday
        } else {
            let reflection = PostActivityReflection(
                activityId: activity.id,
                date: activity.startDate,
                feelingScore: min(5, max(1, feelingScore)),
                pushedTooHard: pushedTooHard,
                wouldRepeatToday: wouldRepeatToday
            )
            modelContext.insert(reflection)
        }
        try? modelContext.save()
    }
}
