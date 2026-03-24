//
//  StoryDetailView.swift
//  Newsletters
//
//  Created by Palmer Nix on 3/24/26.
//

import SwiftUI

struct StoryDetailView: View {
    let item: DigestItem
    let allMetadata: [NewsletterMetadata]
    let onDismiss: () -> Void

    @StateObject private var viewModel = StoryDetailViewModel()

    // Navigation state for "Read in [Name]"
    @State private var navigatingToNewsletter: NewsletterMetadata? = nil
    @State private var scrollToSection: Int? = nil
    @State private var isViewingNewsletter = false

    private let ivoryBg = Color(red: 0.953, green: 0.951, blue: 0.933)

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Headline
                    Text(item.headline)
                        .font(.custom("Georgia-Bold", size: 28))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Description
                    Text(item.description)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Story image (first available)
                    if let imageUrl = item.images?.first?.url, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxHeight: 200)
                                    .clipped()
                                    .cornerRadius(8)
                            default:
                                EmptyView()
                            }
                        }
                    }

                    // Source clippings
                    if viewModel.isLoading {
                        ProgressView("Loading sources…")
                            .padding(.vertical, 20)
                    } else if !viewModel.clippings.isEmpty {
                        ForEach(viewModel.clippings) { clipping in
                            clippingView(clipping)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }

            // Invisible navigation link for "Read in [Name]"
            NavigationLink(
                destination: navigatingToNewsletter.map {
                    NewsletterReaderView(newsletter: $0, scrollToSection: scrollToSection)
                },
                isActive: $isViewingNewsletter
            ) { EmptyView() }
            .opacity(0)
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
        .onAppear {
            viewModel.fetchClippings(for: item, allMetadata: allMetadata)
        }
    }

    // MARK: - Clipping view

    private func clippingView(_ clipping: StoryDetailViewModel.SourceClipping) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Source header
            Text(clipping.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.top, 8)

            // HTML clipping rendered in a WebView
            HTMLWebView(htmlContent: clipping.htmlClipping)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // "Read in [Name]" link
            if clipping.newsletterMetadata != nil {
                Button {
                    navigatingToNewsletter = clipping.newsletterMetadata
                    scrollToSection = clipping.sectionIndex
                    isViewingNewsletter = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 13))
                        Text("Read in \(clipping.displayName)")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }

            Divider()
        }
    }
}
