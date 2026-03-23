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
    @Binding var isNavigating: Bool

    var body: some View {
        VStack(spacing: 0) {
            if !isNavigating {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Newsletters")
                        .font(.custom("Georgia-Bold", size: 40))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    Picker("", selection: $selectedSegment) {
                        Text("Today").tag(0)
                        Text("Historical").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color(red: 0.953, green: 0.951, blue: 0.933))
            }
            if selectedSegment == 0 {
                TodayView(viewModel: viewModel, settingsViewModel: settingsViewModel, isNavigating: $isNavigating)
            } else {
                HistoricalView(viewModel: viewModel, settingsViewModel: settingsViewModel, isNavigating: $isNavigating)
            }
        }
    }
}
