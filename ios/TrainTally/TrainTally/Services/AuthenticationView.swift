//
//  AuthenticationView.swift
//  TrainTally
//
//  Created by Kaleb  Hingsberger on 1/12/26.
//

import SwiftUI

struct AuthenticationView: View {
    @State private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var verificationCode = ""
    @State private var showingVerification = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                if !showingVerification {
                    // Main auth form
                    Section {
                        Picker("Mode", selection: $mode) {
                            Text("Sign In").tag(AuthMode.signIn)
                            Text("Sign Up").tag(AuthMode.signUp)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Section {
                        if mode == .signUp {
                            TextField("Full Name", text: $name)
                                .textContentType(.name)
                                .autocorrectionDisabled()
                        }
                        
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                        
                        SecureField("Password", text: $password)
                            .textContentType(mode == .signUp ? .newPassword : .password)
                        
                        if mode == .signUp {
                            SecureField("Confirm Password", text: $confirmPassword)
                                .textContentType(.newPassword)
                        }
                    }
                    
                    Section {
                        Button(mode == .signIn ? "Sign In" : "Sign Up") {
                            Task {
                                await performAuth()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .disabled(!isFormValid || isLoading)
                    }
                    
                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                } else {
                    // Verification code entry
                    Section {
                        TextField("Verification Code", text: $verificationCode)
                            .textContentType(.oneTimeCode)
                            .keyboardType(.numberPad)
                    } header: {
                        Text("Enter Verification Code")
                    } footer: {
                        Text("Check your email for the verification code")
                    }
                    
                    Section {
                        Button("Verify") {
                            Task {
                                await confirmSignUp()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .disabled(verificationCode.isEmpty || isLoading)
                    }
                }
                
                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(showingVerification ? "Verify Email" : "Authentication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        if showingVerification {
            return !verificationCode.isEmpty
        }
        
        guard !email.isEmpty, !password.isEmpty else {
            return false
        }
        
        if mode == .signUp {
            return !name.isEmpty &&
                   password == confirmPassword &&
                   password.count >= 8
        }
        
        return true
    }
    
    // MARK: - Actions
    
    private func performAuth() async {
        guard isFormValid else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            switch mode {
            case .signIn:
                try await authManager.signIn(email: email, password: password)
                dismiss()
                
            case .signUp:
                try await authManager.signUp(email: email, password: password, name: name)
                // Show verification screen
                showingVerification = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func confirmSignUp() async {
        guard !verificationCode.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authManager.confirmSignUp(email: email, code: verificationCode)
            
            // After confirmation, sign in
            try await authManager.signIn(email: email, password: password)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Supporting Types

enum AuthMode {
    case signIn
    case signUp
}

#Preview {
    AuthenticationView()
}
