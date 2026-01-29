//
//  AuthViewModel.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class AuthViewModel {
    private let authService = AuthService.shared
    
    var isAuthenticated: Bool {
        authService.isAuthenticated
    }
    
    var isLoading: Bool {
        authService.isLoading
    }
    
    var error: AuthError? {
        authService.error
    }
    
    func login() async {
        do {
            try await authService.startOAuthFlow()
        } catch {
            print("Login error: \(error)")
        }
    }
    
    func logout() {
        authService.logout()
    }
    
    func checkAuth() {
        authService.checkAuthStatus()
    }
}
