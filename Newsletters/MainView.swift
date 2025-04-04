//
//  MainView.swift
//  Newsletters
//
//  Created by Palmer Nix on 4/3/25.
//

import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = NewsletterMetadataViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            if selectedTab == 0 {
                TodayView(viewModel: viewModel)
            } else {
                HistoricalView(viewModel: viewModel)
            }
            
            // Custom tab bar at the bottom
            BottomBar(selectedTab: $selectedTab)
        }
        .onAppear {
            // Set up the snapshot listener once on launch.
            viewModel.fetchMetadata()
        }
    }
}



#Preview {
    MainView()
}
