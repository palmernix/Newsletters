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

    private let ivoryBg = Color(red: 0.953, green: 0.951, blue: 0.933)

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Text("Settings")
                        .font(.custom("Georgia-Bold", size: 40))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 14)
                .background(ivoryBg)

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
                    Text("Digest")
                        .font(.custom("Georgia-Bold", size: 22))
                        .textCase(nil)
                        .foregroundColor(.primary)
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
                    NavigationLink(destination: NotificationsMenuView(viewModel: viewModel)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifications")
                                .font(.body)
                            Text("Manage notifications for your active newsletters")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Newsletters")
                        .font(.custom("Georgia-Bold", size: 22))
                        .textCase(nil)
                        .foregroundColor(.primary)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                }

                Section {
                    Button(role: .destructive, action: signOut) {
                        Text("Sign Out")
                    }
                } header: {
                    Text("Account")
                        .font(.custom("Georgia-Bold", size: 22))
                        .textCase(nil)
                        .foregroundColor(.primary)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                }
            }
                .scrollContentBackground(.hidden)
                .background(ivoryBg)
            }
            .navigationBarHidden(true)
            .background(ivoryBg.ignoresSafeArea())
        }
    }

    private func signOut() {
        GIDSignIn.sharedInstance.signOut()
        try? Auth.auth().signOut()
        needsLogin = true
    }
}
