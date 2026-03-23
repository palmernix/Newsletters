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

    private let ivoryBg = Color(red: 0.953, green: 0.951, blue: 0.933)

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                ivoryBg.ignoresSafeArea()

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
            .navigationBarHidden(true)
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
            VStack(alignment: .leading, spacing: 0) {
                headerView
                Divider().padding(.horizontal, 20)
                ForEach(sections, id: \.title) { section in
                    sectionView(section)
                    Divider().padding(.horizontal, 20)
                }
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Daily Digest")
                .font(.custom("Georgia-Bold", size: 40))
                .foregroundColor(.primary)
            Text(formattedDate)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
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
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    expandedSection = isExpanded ? nil : section.title
                }
            } label: {
                HStack {
                    Text(section.title)
                        .font(.custom("Georgia-Bold", size: 26))
                        .foregroundColor(.primary)
                    Spacer()
                    if !isExpanded {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(Color(.systemGray2))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 10) {
                    ForEach(section.items, id: \.headline) { item in
                        itemCard(item)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }
        }
    }

    private func itemCard(_ item: DigestItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 100, height: 100)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.headline)
                    .font(.custom("Georgia-Bold", size: 16))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 6)

                if let source = item.sources.first {
                    sourceLabel(source)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
    }

    private func sourceLabel(_ source: DigestSource) -> some View {
        Button {
            if let meta = metadataViewModel.newsletters
                .first(where: { $0.id == source.newsletterId }) {
                navigatingTo = meta
                isNavigating = true
            }
        } label: {
            HStack(spacing: 5) {
                Text(String(source.displayName.prefix(1)))
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 14, height: 14)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                Text(source.displayName)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
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
