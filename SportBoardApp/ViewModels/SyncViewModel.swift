//
//  SyncViewModel.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class SyncViewModel: ObservableObject {
    private let syncService = SyncService.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var progress: SyncProgress
    
    init() {
        self.progress = syncService.progress
        
        // Observar cambios en el progress del servicio
        syncService.progress.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        syncService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    var isActive: Bool {
        progress.isActive
    }
    
    var isPaused: Bool {
        progress.phase == .paused
    }
    
    var isRateLimited: Bool {
        progress.isRateLimited
    }
    
    var hasError: Bool {
        progress.phase == .error
    }
    
    var isCancelled: Bool {
        syncService.isCancelled
    }
    
    func configure(modelContext: ModelContext) {
        syncService.configure(modelContext: modelContext)
    }
    
    func startSync(fullSync: Bool = false) {
        syncService.startSync(fullSync: fullSync)
    }
    
    func cancelSync() {
        syncService.cancelSync()
    }
    
    func resumeSync() {
        syncService.resumeSync()
    }
}
