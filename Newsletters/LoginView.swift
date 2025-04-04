//
//  LoginView.swift
//  Newsletters
//
//  Created by Palmer Nix on 4/3/25.
//

import SwiftUI
import KeychainAccess
import FirebaseAuth

struct LoginView: View {
    @Binding var needsLogin: Bool
    @State private var email: String = ""
    @State private var password: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter Credentials")
                .font(.headline)
            TextField("Email", text: $email)
                .autocapitalization(.none)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            Button("Save and Sign In") {
                saveCredentials(email: email, password: password)
                signIn(email: email, password: password)
            }
            .padding()
        }
    }
    
    func saveCredentials(email: String, password: String) {
        let keychain = Keychain(service: "com.palmernix.Newsletters")
        do {
            try keychain.set(email, key: "userEmail")
            try keychain.set(password, key: "userPassword")
            print("Credentials saved.")
        } catch let error {
            print("Error saving credentials: \(error)")
        }
    }
    
    func signIn(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                print("Sign in error: \(error.localizedDescription)")
            } else {
                print("Signed in successfully.")
                // Switch to the main content view
                needsLogin = false
            }
        }
    }
}
