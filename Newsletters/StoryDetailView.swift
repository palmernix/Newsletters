//
//  StoryDetailView.swift
//  Newsletters
//
//  Created by Palmer Nix on 3/24/26.
//

import SwiftUI

struct StoryDetailView: View {
    let item: DigestItem
    let onDismiss: () -> Void

    private let ivoryBg = Color(red: 0.953, green: 0.951, blue: 0.933)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(item.headline)
                    .font(.custom("Georgia-Bold", size: 28))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.description)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(ivoryBg.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onDismiss) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
    }
}
