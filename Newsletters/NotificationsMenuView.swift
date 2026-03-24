//
//  NotificationsMenuView.swift
//  Newsletters
//
//  Created by Palmer Nix on 3/17/26.
//

import SwiftUI

struct NotificationsMenuView: View {
    @ObservedObject var viewModel: SettingsViewModel

    private var enabledNewsletters: [Newsletter] {
        Newsletter.allCases.filter { viewModel.isEnabled($0) }
    }

    var body: some View {
        List {
            if enabledNewsletters.isEmpty {
                Text("No newsletters are currently enabled. Enable newsletters in the Newsletter Menu first.")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(enabledNewsletters) { newsletter in
                    Toggle(isOn: Binding(
                        get: { viewModel.isNotificationEnabled(newsletter) },
                        set: { _ in viewModel.toggleNotification(newsletter) }
                    )) {
                        Text(newsletter.displayName)
                            .font(.body)
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}
