//
//  NewslettersApp.swift
//  Newsletters
//
//  Created by Palmer Nix on 4/3/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import KeychainAccess

@main
struct NewslettersApp: App {
    @State private var needsLogin: Bool = false

    init() {
        FirebaseApp.configure()

        if Auth.auth().currentUser != nil {
            // Firebase already has a persisted session (Google or email/password)
            _needsLogin = State(initialValue: false)
        } else if areCredentialsStored() {
            // Fall back to keychain for existing email/password users
            _needsLogin = State(initialValue: false)
            signInWithStoredCredentials()
        } else {
            _needsLogin = State(initialValue: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if needsLogin {
                    LoginView(needsLogin: $needsLogin)
                } else {
                    MainView(needsLogin: $needsLogin)
                }
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
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
        let keychain = Keychain(service: "com.palmernix.Newsletters")
        if let email = try? keychain.get("userEmail"),
           let password = try? keychain.get("userPassword"),
           !email.isEmpty, !password.isEmpty {
            Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    print("Error signing in: \(error.localizedDescription)")
                } else {
                    print("Signed in: \(authResult?.user.uid ?? "")")
                }
            }
        }
    }
}
