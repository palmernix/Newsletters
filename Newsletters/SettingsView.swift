//
//  SettingsView.swift
//  Newsletters
//
//  Created by Palmer Nix on 3/17/26.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationView {
            List {
                Section(header:
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Newsletter Menu")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("Choose which newsletters appear in your feed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .textCase(nil)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                ) {
                    EmptyView()
                }

                ForEach(NewsletterGroup.allCases, id: \.rawValue) { group in
                    let newsletters = Newsletter.newsletters(for: group)
                    Section(header: Text(group.rawValue)) {
                        ForEach(newsletters) { newsletter in
                            toggleRow(for: newsletter)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func toggleRow(for newsletter: Newsletter) -> some View {
        Toggle(isOn: Binding(
            get: { viewModel.isEnabled(newsletter) },
            set: { _ in viewModel.toggle(newsletter) }
        )) {
            Text(newsletter.displayName)
                .font(.body)
        }
    }
}
