//
//  SettingsView.swift
//  Newsletters
//
//  Created by Palmer Nix on 3/17/26.
//

import SwiftUI
import FirebaseAuth
import GoogleSignIn

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Binding var needsLogin: Bool

    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink(destination: DigestSectionOrderView(viewModel: viewModel)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Digest Section Order")
                                .font(.body)
                            Text("Customise the order sections appear in your digest")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Digest")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .textCase(nil)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }

                Section {
                    NavigationLink(destination: NewsletterMenuView(viewModel: viewModel)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Newsletter Menu")
                                .font(.body)
                            Text("Choose which newsletters appear in your feed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Newsletters")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .textCase(nil)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
            }
                Section {
                    Button(role: .destructive, action: signOut) {
                        Text("Sign Out")
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Account")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .textCase(nil)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
            .navigationTitle("Settings")
        }
    }

    private func signOut() {
        GIDSignIn.sharedInstance.signOut()
        try? Auth.auth().signOut()
        needsLogin = true
    }
}
