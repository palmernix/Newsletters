//
//  MainView.swift
//  Newsletters
//
//  Created by Palmer Nix on 4/3/25.
//

import SwiftUI
import FirebaseAuth

struct MainView: View {
    @Binding var needsLogin: Bool
    @StateObject private var viewModel = NewsletterMetadataViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var selectedTab = 1
    @State private var authListenerHandle: AuthStateDidChangeListenerHandle? = nil
    @State private var didEstablishAuth = false

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            if selectedTab == 0 {
                DigestView(metadataViewModel: viewModel, settingsViewModel: settingsViewModel)
            } else if selectedTab == 1 {
                NewslettersView(viewModel: viewModel, settingsViewModel: settingsViewModel)
            } else {
                SettingsView(viewModel: settingsViewModel, needsLogin: $needsLogin)
            }

            // Custom tab bar at the bottom
            BottomBar(selectedTab: $selectedTab)
        }
        .onAppear {
            // Set up the snapshot listeners once on launch.
            viewModel.fetchMetadata()
            settingsViewModel.fetchSettings()
            settingsViewModel.fetchDigestCategories()
            settingsViewModel.syncSenderFilters()

            // Redirect to login if auth is lost while the app is running.
            authListenerHandle = Auth.auth().addStateDidChangeListener { _, user in
                DispatchQueue.main.async {
                    if user != nil {
                        didEstablishAuth = true
                    } else if didEstablishAuth {
                        needsLogin = true
                    }
                }
            }
        }
        .onDisappear {
            authListenerHandle.map { Auth.auth().removeStateDidChangeListener($0) }
            authListenerHandle = nil
        }
    }
}



#Preview {
    MainView(needsLogin: .constant(false))
}
