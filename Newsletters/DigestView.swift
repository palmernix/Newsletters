//
//  DigestView.swift
//  Newsletters
//
//  Created by Palmer Nix on 3/17/26.
//

import SwiftUI

struct DigestView: View {
    @StateObject private var digestVM = DigestViewModel()
    @ObservedObject var metadataViewModel: NewsletterMetadataViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel

    // Navigation state (mirrors TodayView/HistoricalView pattern)
    @State private var navigatingTo: NewsletterMetadata? = nil
    @State private var isNavigating = false
    @State private var showRefreshBanner = false
    @State private var expandedSection: String? = nil
    @State private var expandedItem: String? = nil

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                switch digestVM.state {
                case .idle:
                    EmptyView()
                case .loading:
                    ProgressView("Generating digest…")
                case .loaded(let digest):
                    digestContent(digest)
                case .empty(let reason):
                    emptyState(reason)
                case .error(let stale):
                    errorState(stale)
                }

                // Invisible navigation link (existing app pattern)
                NavigationLink(
                    destination: navigatingTo.map { NewsletterReaderView(newsletter: $0) },
                    isActive: $isNavigating
                ) { EmptyView() }
                .opacity(0)

                // New-newsletters toast
                if showRefreshBanner {
                    RefreshToast()
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture {
                            withAnimation { showRefreshBanner = false }
                            digestVM.refresh(
                                todayNewsletters: metadataViewModel.newsletters,
                                enabledEmails: settingsViewModel.enabledNewsletters
                            )
                        }
                }
            }
            .navigationTitle("Digest")
            .toolbar {
                if digestVM.refreshAvailable {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Refresh") {
                            digestVM.refresh(
                                todayNewsletters: metadataViewModel.newsletters,
                                enabledEmails: settingsViewModel.enabledNewsletters
                            )
                        }
                    }
                }
            }
            .onChange(of: digestVM.refreshAvailable) { available in
                if available {
                    withAnimation { showRefreshBanner = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation { showRefreshBanner = false }
                    }
                } else {
                    withAnimation { showRefreshBanner = false }
                }
            }
            .onAppear {
                digestVM.checkAndGenerate(
                    todayNewsletters: metadataViewModel.newsletters,
                    enabledEmails: settingsViewModel.enabledNewsletters
                )
            }
        }
    }

    // MARK: - Digest content

    private func digestContent(_ digest: DigestDocument) -> some View {
        let sections = sortedSections(digest.sections)
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(sections, id: \.title) { section in
                    sectionView(section)
                }
            }
            .padding()
        }
    }

    private func sortedSections(_ sections: [DigestSection]) -> [DigestSection] {
        let order = settingsViewModel.sectionOrder
        guard !order.isEmpty else { return sections }
        return sections.sorted { a, b in
            let ai = order.firstIndex(of: a.title) ?? Int.max
            let bi = order.firstIndex(of: b.title) ?? Int.max
            return ai < bi
        }
    }

    private func sectionView(_ section: DigestSection) -> some View {
        let isExpanded = expandedSection == section.title
        return VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedSection = isExpanded ? nil : section.title
                }
            }) {
                HStack(alignment: .center, spacing: 6) {
                    Text(section.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(section.items, id: \.headline) { item in
                        itemView(item)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private func itemView(_ item: DigestItem) -> some View {
        let isExpanded = expandedItem == item.headline
        return VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedItem = isExpanded ? nil : item.headline
                }
            }) {
                HStack {
                    Text(item.headline)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                    FlowLayout(spacing: 6) {
                        ForEach(item.sources, id: \.newsletterId) { source in
                            sourceChip(source)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    private func sourceChip(_ source: DigestSource) -> some View {
        Button(action: {
            if let meta = metadataViewModel.newsletters
                .first(where: { $0.id == source.newsletterId }) {
                navigatingTo = meta
                isNavigating = true
            }
        }) {
            Text(source.displayName)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.15))
                .foregroundColor(.accentColor)
                .cornerRadius(12)
        }
    }

    // MARK: - Empty / Error states

    private func emptyState(_ reason: EmptyReason) -> some View {
        VStack(spacing: 12) {
            Spacer()
            switch reason {
            case .noNewslettersToday:
                Text("No newsletters received yet today, check back later")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            case .noneEnabled:
                Text("No newsletters enabled. Enable newsletters in Settings to generate a digest.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding()
    }

    private func errorState(_ stale: DigestDocument?) -> some View {
        VStack(spacing: 16) {
            if let stale {
                Banner(message: "Digest may be outdated — couldn't reach the server.")
                digestContent(stale)
            } else {
                Spacer()
                Text("Couldn't generate digest. Please try again.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    digestVM.checkAndGenerate(
                        todayNewsletters: metadataViewModel.newsletters,
                        enabledEmails: settingsViewModel.enabledNewsletters
                    )
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
        }
    }
}

// MARK: - Small helpers

private struct RefreshToast: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "envelope.badge")
                .foregroundColor(.accentColor)
            Text("New newsletters available — tap to refresh")
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(radius: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

private struct Banner: View {
    let message: String
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }
}

/// Simple flow layout for wrapping chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(subviews: subviews, width: proposal.width ?? 0).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, width: bounds.width)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func layout(subviews: Subviews, width: CGFloat) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), frames)
    }
}
