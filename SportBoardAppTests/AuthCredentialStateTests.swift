//
//  AuthCredentialStateTests.swift
//  SportBoardAppTests
//

import XCTest
@testable import SportBoardApp

final class AuthCredentialStateTests: XCTestCase {
    func testExpiredAccessTokenWithRefreshTokenKeepsSessionUsable() {
        let credentials = StoredStravaCredentials(
            accessToken: "expired-access-token",
            refreshToken: "refresh-token",
            expiresAt: 1_000
        )

        XCTAssertTrue(credentials.hasUsableSession(now: 2_000))
    }

    func testExpiredAccessTokenWithoutRefreshTokenDoesNotKeepSessionUsable() {
        let credentials = StoredStravaCredentials(
            accessToken: "expired-access-token",
            refreshToken: nil,
            expiresAt: 1_000
        )

        XCTAssertFalse(credentials.hasUsableSession(now: 2_000))
    }

    func testValidAccessTokenKeepsSessionUsableWithoutRefreshToken() {
        let credentials = StoredStravaCredentials(
            accessToken: "valid-access-token",
            refreshToken: nil,
            expiresAt: 3_000
        )

        XCTAssertTrue(credentials.hasUsableSession(now: 2_000))
    }
}
