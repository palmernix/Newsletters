//
//  DigestSectionOrderView.swift
//  Newsletters
//
//  Created by Palmer Nix on 3/17/26.
//

import SwiftUI

struct DigestSectionOrderView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        List {
            ForEach(viewModel.sectionOrder, id: \.self) { title in
                Label(title, systemImage: "line.3.horizontal")
                    .foregroundColor(.primary)
            }
            .onMove { viewModel.moveSections(from: $0, to: $1) }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Section Order")
        .navigationBarTitleDisplayMode(.inline)
    }
}
