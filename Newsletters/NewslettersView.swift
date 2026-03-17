//
//  NewslettersView.swift
//  Newsletters
//
//  Created by Palmer Nix on 3/17/26.
//

import SwiftUI

struct NewslettersView: View {
    @ObservedObject var viewModel: NewsletterMetadataViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @State private var selectedSegment = 0

    var body: some View {
        VStack(spacing: 0) {
            if selectedSegment == 0 {
                TodayView(viewModel: viewModel, settingsViewModel: settingsViewModel)
            } else {
                HistoricalView(viewModel: viewModel, settingsViewModel: settingsViewModel)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("", selection: $selectedSegment) {
                Text("Today").tag(0)
                Text("Historical").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(Color(UIColor.systemBackground))
        }
    }
}
