//
//  AuthenticationManager.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 1/12/26.
//

import Foundation
import Amplify
import AWSCognitoAuthPlugin
import AWSPluginsCore
import Combine
import Observation

/// Manages AWS Cognito authentication state
@MainActor
@Observable
class AuthenticationManager {
    static let shared = AuthenticationManager()
    
    var isAuthenticated = false
    var currentUser: AuthUser?
    var authError: String?
    
    /// Computed property to get the current user's email
    var currentUserEmail: String? {
        currentUser?.username
    }
    
    private init() {
        checkAuthStatus()
    }
    
    // MARK: - Auth Status
    
    /// Check current authentication status
    func checkAuthStatus() {
        Task {
            do {
                let session = try await Amplify.Auth.fetchAuthSession()
                isAuthenticated = session.isSignedIn
                
                if isAuthenticated {
                    currentUser = try await Amplify.Auth.getCurrentUser()
                }
            } catch {
                print("Failed to fetch auth session: \(error)")
                isAuthenticated = false
                currentUser = nil
            }
        }
    }
    
    // MARK: - Sign Up
    
    /// Sign up a new user with email and password
    func signUp(email: String, password: String, name: String) async throws {
        let userAttributes = [
            AuthUserAttribute(.email, value: email),
            AuthUserAttribute(.name, value: name)
        ]
        
        let options = AuthSignUpRequest.Options(userAttributes: userAttributes)
        
        let result = try await Amplify.Auth.signUp(
            username: email,
            password: password,
            options: options
        )
        
        // Handle sign up result
        switch result.nextStep {
        case .confirmUser(let deliveryDetails, _, _):
            print("Sign up complete. Confirmation code sent to: \(String(describing: deliveryDetails))")
        case .done:
            print("Sign up complete")
        case .completeAutoSignIn(_):
            print("Auto sign-in after sign up")
        @unknown default:
            print("Unexpected sign up step")
        }
    }
    
    /// Confirm sign up with verification code
    func confirmSignUp(email: String, code: String) async throws {
        print("📧 AuthManager: Confirming sign up for email: \(email)")
        print("📧 AuthManager: Using code: \(code)")
        
        let result = try await Amplify.Auth.confirmSignUp(
            for: email,
            confirmationCode: code
        )
        
        print("📧 AuthManager: Confirm result - isSignUpComplete: \(result.isSignUpComplete)")
        
        if result.isSignUpComplete {
            print("✅ AuthManager: Email confirmed successfully")
        } else {
            print("⚠️ AuthManager: Sign up not complete yet")
        }
    }
    
    // MARK: - Sign In
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async throws {
        let result = try await Amplify.Auth.signIn(
            username: email,
            password: password
        )
        
        if result.isSignedIn {
            isAuthenticated = true
            currentUser = try await Amplify.Auth.getCurrentUser()
            authError = nil
        }
    }
    
    // MARK: - Sign Out
    
    /// Sign out the current user
    func signOut() async {
        do {
            _ = await Amplify.Auth.signOut()
            isAuthenticated = false
            currentUser = nil
            authError = nil
        }
    }
    
    // MARK: - Password Reset
    
    /// Request password reset code
    func resetPassword(email: String) async throws {
        try await Amplify.Auth.resetPassword(for: email)
    }
    
    /// Confirm password reset with code
    func confirmResetPassword(email: String, newPassword: String, code: String) async throws {
        try await Amplify.Auth.confirmResetPassword(
            for: email,
            with: newPassword,
            confirmationCode: code
        )
    }
    
    // MARK: - Tokens
    
    /// Get the current auth token for API calls
    func getAuthToken() async throws -> String {
        let session = try await Amplify.Auth.fetchAuthSession()
        
        // Try to get the ID token from the Cognito session
        if let cognitoSession = session as? AuthCognitoTokensProvider {
            do {
                let tokens = try cognitoSession.getCognitoTokens().get()
                return tokens.idToken
            } catch {
                print("Failed to get ID token: \(error)")
                throw AuthError.unknown("Could not get Cognito token: \(error.localizedDescription)")
            }
        }
        
        throw AuthError.unknown("Session is not a Cognito session")
    }
    
    /// Get user ID (sub claim from JWT)
    func getUserId() async throws -> String {
        let token = try await getAuthToken()
        
        // Parse JWT to get sub claim
        let parts = token.split(separator: ".")
        guard parts.count == 3 else {
            throw AuthError.unknown("Invalid JWT token")
        }
        
        // Decode payload (second part)
        let payloadData = parts[1]
        var base64 = String(payloadData)
        
        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        // Replace URL-safe characters
        base64 = base64.replacingOccurrences(of: "-", with: "+")
        base64 = base64.replacingOccurrences(of: "_", with: "/")
        
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else {
            throw AuthError.unknown("Could not extract user ID from token")
        }
        
        return sub
    }
}

// MARK: - Auth Error

enum AuthError: LocalizedError {
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .unknown(let message):
            return message
        }
    }
}
