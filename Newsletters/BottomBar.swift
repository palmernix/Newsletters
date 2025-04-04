//
//  BottomBar.swift
//  Newsletters
//
//  Created by Palmer Nix on 4/3/25.
//

import SwiftUI

struct BottomBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            Button(action: { selectedTab = 0 }) {
                Text("Today")
                    .frame(maxWidth: .infinity)
            }
            
            // Insert a vertical divider
            Divider()
                .frame(height: 30)
                .padding(.vertical, 8)
            
            Button(action: { selectedTab = 1 }) {
                Text("Historical")
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .frame(height: 50)
        .background(Color(UIColor.systemBackground))
        .shadow(radius: 2)
    }
}
