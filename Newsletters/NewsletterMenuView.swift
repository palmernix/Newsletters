//
//  NewsletterMenuView.swift
//  Newsletters
//
//  Created by Palmer Nix on 3/17/26.
//

import SwiftUI

struct NewsletterMenuView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        List {
            ForEach(NewsletterGroup.allCases, id: \.rawValue) { group in
                let newsletters = Newsletter.newsletters(for: group)
                Section(header: Text(group.rawValue)) {
                    ForEach(newsletters) { newsletter in
                        newsletterRow(for: newsletter)
                    }
                }
            }
        }
        .navigationTitle("Newsletter Menu")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func newsletterRow(for newsletter: Newsletter) -> some View {
        Toggle(isOn: Binding(
            get: { viewModel.isEnabled(newsletter) },
            set: { _ in viewModel.toggle(newsletter) }
        )) {
            Text(newsletter.displayName)
                .font(.body)
        }
    }
}
