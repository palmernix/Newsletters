//
//  MainView.swift
//  Newsletters
//
//  Created by Palmer Nix on 4/3/25.
//

import SwiftUI

struct MainView: View {
    @Binding var needsLogin: Bool
    @StateObject private var viewModel = NewsletterMetadataViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var selectedTab = 1

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
        }
    }
}



#Preview {
    MainView(needsLogin: .constant(false))
}
