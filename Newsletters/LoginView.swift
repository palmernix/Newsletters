//
//  LoginView.swift
//  Newsletters
//
//  Created by Palmer Nix on 4/3/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import KeychainAccess

struct LoginView: View {
    @Binding var needsLogin: Bool
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var showEmailSignIn = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Synpsis")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Sign in to continue")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            // Google Sign-In
            GoogleSignInButton(scheme: .dark, style: .wide, state: .normal) {
                signInWithGoogle()
            }
            .frame(height: 50)
            .padding(.horizontal, 32)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Email/password fallback (owner only)
            if showEmailSignIn {
                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .autocapitalization(.none)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Sign In") {
                        saveCredentials(email: email, password: password)
                        signInWithEmail(email: email, password: password)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 32)
            }

            Spacer()

            Button(showEmailSignIn ? "Hide email sign in" : "Sign in with email") {
                showEmailSignIn.toggle()
            }
            .font(.footnote)
            .foregroundColor(.secondary)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            if let error = error {
                errorMessage = "Sign-in failed. Please try again."
                print("Google Sign-In error: \(error)")
                return
            }
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else { return }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { _, error in
                if let error = error {
                    errorMessage = "Sign-in failed. Please try again."
                    print("Firebase Sign-In error: \(error)")
                    return
                }
                needsLogin = false
            }
        }
    }

    // MARK: - Email Sign-In

    func saveCredentials(email: String, password: String) {
        let keychain = Keychain(service: "com.palmernix.Newsletters")
        try? keychain.set(email, key: "userEmail")
        try? keychain.set(password, key: "userPassword")
    }

    func signInWithEmail(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            needsLogin = false
        }
    }
}
