//
//  NewsletterMenuView.swift
//  Newsletters
//
//  Created by Palmer Nix on 3/17/26.
//

import SwiftUI

struct NewsletterMenuView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var newsletterStore: NewsletterStore

    var body: some View {
        List {
            ForEach(newsletterStore.groups, id: \.self) { group in
                let newsletters = newsletterStore.newsletters(for: group)
                Section(header: Text(group)) {
                    ForEach(newsletters) { newsletter in
                        newsletterRow(for: newsletter)
                    }
                }
            }
        }
        .navigationTitle("Newsletter Menu")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func newsletterRow(for newsletter: NewsletterInfo) -> some View {
        Toggle(isOn: Binding(
            get: { viewModel.isEnabled(newsletter) },
            set: { _ in viewModel.toggle(newsletter) }
        )) {
            Text(newsletter.displayName)
                .font(.body)
        }
    }
}
