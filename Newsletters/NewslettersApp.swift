//
//  NewslettersApp.swift
//  Newsletters
//
//  Created by Palmer Nix on 4/3/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import KeychainAccess

@main
struct NewslettersApp: App {
    @State private var needsLogin: Bool = false
    
    init() {
        FirebaseApp.configure();
        
        if !areCredentialsStored() {
            // If not stored, set a flag to show the login UI.
            _needsLogin = State(initialValue: true)
        } else {
            signInWithStoredCredentials()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if needsLogin {
                LoginView(needsLogin: $needsLogin)
            } else {
                MainView()
            }
        }
    }
    
    func areCredentialsStored() -> Bool {
        let keychain = Keychain(service: "com.palmernix.Newsletters")
        if let email = try? keychain.get("userEmail"),
           let password = try? keychain.get("userPassword"),
           !email.isEmpty, !password.isEmpty {
            return true
        }
        return false
    }
    
    func signInWithStoredCredentials() {
        print("Authenticating user.")
        let keychain = Keychain(service: "com.palmernix.Newsletters")
        if let email = try? keychain.get("userEmail"),
           let password = try? keychain.get("userPassword"),
           !email.isEmpty, !password.isEmpty {
            
            Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    print("Error signing in: \(error.localizedDescription)")
                } else {
                    print("Successfully signed in with user id: \(authResult?.user.uid ?? "Unknown")")
                }
            }
        } else {
            print("Stored credentials not found in Keychain.")
        }
    }
}
