//
//  AuthService.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import Foundation
import UIKit
import AuthenticationServices
import Combine

// MARK: - Auth Errors

enum AuthError: LocalizedError, Equatable {
    case invalidURL
    case noAuthCode
    case tokenExchangeFailed(String)
    case noAccessToken
    case refreshFailed
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL de autorización inválida"
        case .noAuthCode: return "No se recibió código de autorización"
        case .tokenExchangeFailed(let msg): return "Error al obtener token: \(msg)"
        case .noAccessToken: return "No hay token de acceso"
        case .refreshFailed: return "Error al refrescar el token"
        case .cancelled: return "Autenticación cancelada"
        }
    }
}

// MARK: - Token Response

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int
    let athlete: AthleteResponse?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case athlete
    }
}

// MARK: - Auth Service

@MainActor
final class AuthService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = AuthService()
    
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: AuthError?
    
    private let keychain = KeychainHelper.shared
    private var authSession: ASWebAuthenticationSession?
    
    override init() {
        super.init()
        checkAuthenticationStatus()
    }
    
    // MARK: - Public Methods
    
    /// Inicia el flujo de OAuth con Strava
    func startOAuthFlow() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        guard let authURL = URL(string: Constants.Strava.authorizeURL + "?client_id=\(Constants.Strava.clientId)&redirect_uri=\(Constants.Strava.redirectUri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&response_type=code&scope=\(Constants.Strava.scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            throw AuthError.invalidURL
        }
        
        let authCode = try await performWebAuth(url: authURL)
        try await exchangeCodeForToken(code: authCode)
    }
    
    /// Obtiene el token de acceso actual (refresca si es necesario)
    func getAccessToken() async throws -> String {
        if let token = keychain.readString(forKey: Constants.Keychain.accessTokenKey) {
            // Verificar si está expirado
            if let expiresAt = keychain.readInt(forKey: Constants.Keychain.expiresAtKey),
               expiresAt > Int(Date().timeIntervalSince1970) {
                return token
            }
            
            // Intentar refrescar
            if let refreshToken = keychain.readString(forKey: Constants.Keychain.refreshTokenKey) {
                try await refreshAccessToken(refreshToken)
                if let newToken = keychain.readString(forKey: Constants.Keychain.accessTokenKey) {
                    return newToken
                }
            }
        }
        
        throw AuthError.noAccessToken
    }
    
    /// Cierra sesión
    func logout() {
        keychain.clearAll()
        isAuthenticated = false
    }
    
    /// Verifica el estado de autenticación (método público)
    func checkAuthStatus() {
        checkAuthenticationStatus()
    }
    
    // MARK: - Private Methods
    
    private func performWebAuth(url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "sportboardapp",
                completionHandler: { [weak self] callbackURL, error in
                    // Limpiar la referencia a la sesión cuando termine
                    self?.authSession = nil
                    
                    if let error = error {
                        if let nsError = error as NSError?,
                           nsError.domain == ASWebAuthenticationSessionErrorDomain,
                           nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                            continuation.resume(throwing: AuthError.cancelled)
                        } else {
                            continuation.resume(throwing: AuthError.noAuthCode)
                        }
                        return
                    }
                    
                    guard let callbackURL = callbackURL,
                          let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                          let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                        continuation.resume(throwing: AuthError.noAuthCode)
                        return
                    }
                    
                    continuation.resume(returning: code)
                }
            )
            
            // Guardar la sesión en una propiedad fuerte para que no se libere
            authSession = session
            authSession?.presentationContextProvider = self as ASWebAuthenticationPresentationContextProviding
            authSession?.prefersEphemeralWebBrowserSession = false
            
            if !session.start() {
                authSession = nil
                continuation.resume(throwing: AuthError.invalidURL)
            }
        }
    }
    
    private func exchangeCodeForToken(code: String) async throws {
        guard let url = URL(string: Constants.Strava.tokenURL) else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "client_id": Constants.Strava.clientId,
            "client_secret": Constants.Strava.clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AuthError.tokenExchangeFailed(errorMessage)
        }
        
        let decoder = JSONDecoder()
        let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
        
        // Guardar tokens en Keychain
        _ = keychain.save(tokenResponse.accessToken, forKey: Constants.Keychain.accessTokenKey)
        _ = keychain.save(tokenResponse.refreshToken, forKey: Constants.Keychain.refreshTokenKey)
        _ = keychain.save(tokenResponse.expiresAt, forKey: Constants.Keychain.expiresAtKey)
        
        if let athlete = tokenResponse.athlete {
            _ = keychain.save(Int(athlete.id), forKey: Constants.Keychain.athleteIdKey)
        }
        
        isAuthenticated = true
    }
    
    private func refreshAccessToken(_ refreshToken: String) async throws {
        guard let url = URL(string: Constants.Strava.tokenURL) else {
            throw AuthError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "client_id": Constants.Strava.clientId,
            "client_secret": Constants.Strava.clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.refreshFailed
        }
        
        let decoder = JSONDecoder()
        let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
        
        // Actualizar tokens en Keychain
        _ = keychain.save(tokenResponse.accessToken, forKey: Constants.Keychain.accessTokenKey)
        _ = keychain.save(tokenResponse.refreshToken, forKey: Constants.Keychain.refreshTokenKey)
        _ = keychain.save(tokenResponse.expiresAt, forKey: Constants.Keychain.expiresAtKey)
    }
    
    private func checkAuthenticationStatus() {
        if let _ = keychain.readString(forKey: Constants.Keychain.accessTokenKey) {
            // Verificar si no está expirado
            if let expiresAt = keychain.readInt(forKey: Constants.Keychain.expiresAtKey),
               expiresAt > Int(Date().timeIntervalSince1970) {
                isAuthenticated = true
            }
        }
    }
    
#if canImport(AuthenticationServices)
    // MARK: - ASWebAuthenticationPresentationContextProviding
    @objc
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Obtener la ventana real de la app desde windowScene
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            #if DEBUG
            fatalError("No window scene available for ASWebAuthenticationSession")
            #else
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene,
                   let window = windowScene.windows.first {
                    return window
                }
            }
            fatalError("No window available for ASWebAuthenticationSession")
            #endif
        }
        if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return keyWindow
        }
        if let firstWindow = windowScene.windows.first {
            return firstWindow
        }
        #if DEBUG
        fatalError("No key window available for ASWebAuthenticationSession")
        #else
        fatalError("No window available for ASWebAuthenticationSession")
        #endif
    }
#endif
}

