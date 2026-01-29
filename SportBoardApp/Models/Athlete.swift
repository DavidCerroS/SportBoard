//
//  Athlete.swift
//  SportBoardApp
//
//  Created by David on 28/1/26.
//

import Foundation
import SwiftData

@Model
final class Athlete {
    @Attribute(.unique) var id: Int64
    var username: String?
    var firstName: String
    var lastName: String
    var city: String?
    var country: String?
    var profileImageURL: String?
    var profileMediumImageURL: String?
    var premium: Bool
    var createdAt: Date?
    var updatedAt: Date?
    
    // Estadísticas (opcional, se pueden calcular de las actividades)
    var totalActivities: Int
    var totalDistance: Double
    var totalMovingTime: Int
    
    init(
        id: Int64,
        username: String? = nil,
        firstName: String,
        lastName: String,
        city: String? = nil,
        country: String? = nil,
        profileImageURL: String? = nil,
        profileMediumImageURL: String? = nil,
        premium: Bool = false,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        totalActivities: Int = 0,
        totalDistance: Double = 0,
        totalMovingTime: Int = 0
    ) {
        self.id = id
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
        self.city = city
        self.country = country
        self.profileImageURL = profileImageURL
        self.profileMediumImageURL = profileMediumImageURL
        self.premium = premium
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.totalActivities = totalActivities
        self.totalDistance = totalDistance
        self.totalMovingTime = totalMovingTime
    }
}

// MARK: - Computed Properties

extension Athlete {
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var displayName: String {
        username ?? fullName
    }
    
    var location: String? {
        [city, country].compactMap { $0 }.joined(separator: ", ")
    }
}
