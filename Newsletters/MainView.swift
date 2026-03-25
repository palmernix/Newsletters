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
    @StateObject private var newsletterStore = NewsletterStore()
    @State private var selectedTab = 1
    @State private var isNavigatingToReader = false
    @State private var authListenerHandle: AuthStateDidChangeListenerHandle? = nil
    @State private var didEstablishAuth = false

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            if selectedTab == 0 {
                DigestView(metadataViewModel: viewModel, settingsViewModel: settingsViewModel, newsletterStore: newsletterStore, isNavigating: $isNavigatingToReader)
            } else if selectedTab == 1 {
                NewslettersView(viewModel: viewModel, settingsViewModel: settingsViewModel, isNavigating: $isNavigatingToReader)
            } else {
                SettingsView(viewModel: settingsViewModel, newsletterStore: newsletterStore, needsLogin: $needsLogin)
            }

            // Custom tab bar at the bottom — hidden while reading a newsletter
            if !isNavigatingToReader {
                BottomBar(selectedTab: $selectedTab)
            }
        }
        // Stale navigation flag can't carry over when the user switches tabs
        .onChange(of: selectedTab) { _ in isNavigatingToReader = false }
        .onAppear {
            // Load newsletter config from Firestore, then set up dependencies.
            newsletterStore.load()
            settingsViewModel.newsletterStore = newsletterStore
            settingsViewModel.fetchSettings()
            settingsViewModel.fetchDigestCategories()

            viewModel.fetchMetadata()

            // Inject store into digest view model (created lazily in DigestView)
            // This is handled by DigestView passing the store through.

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
