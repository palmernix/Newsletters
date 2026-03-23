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
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                tabItem(icon: "doc.text",     selectedIcon: "doc.text.fill",  label: "Digest",      tab: 0)
                tabItem(icon: "text.alignleft", selectedIcon: "text.alignleft", label: "Newsletters", tab: 1)
                tabItem(icon: "gearshape",    selectedIcon: "gearshape.fill", label: "Settings",    tab: 2)
            }
            .padding(.top, 6)
            .padding(.bottom, 8)
        }
        .background(Color(UIColor.systemBackground).ignoresSafeArea(edges: .bottom))
    }

    private func tabItem(icon: String, selectedIcon: String, label: String, tab: Int) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? selectedIcon : icon)
                    .font(.system(size: 22))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(isSelected ? .accentColor : Color(.systemGray))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
