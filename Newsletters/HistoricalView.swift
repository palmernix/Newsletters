import SwiftUI
import FirebaseFirestore

struct HistoricalView: View {
    @ObservedObject var viewModel: NewsletterMetadataViewModel
    @State private var expandedGroup: String? = nil
    @State private var selectedNewsletter: NewsletterMetadata?
    @State private var showingActionSheet = false
    @State private var isNavigating = false

    private var historicalNewsletters: [NewsletterMetadata] {
        viewModel.newsletters.filter {
            !Calendar.current.isDateInToday($0.newsletterDate)
        }
    }

    private var groupedNewsletters: [String: [NewsletterMetadata]] {
        historicalNewsletters.groupedForHistorical()
    }

    private let customOrder = [
        "The New York Times: The Morning",
        "The New York Times: The Evening",
        "The New York Times: Breaking News",
        "The New York Times: Climate",
        "Morning Brew",
        "Tech Brew",
        "IT Brew",
        "Sigma Xi",
        "HEATED"
    ]

    private var sortedKeys: [String] {
        groupedNewsletters.keys.sorted { key1, key2 in
            let idx1 = customOrder.firstIndex(of: key1) ?? Int.max
            let idx2 = customOrder.firstIndex(of: key2) ?? Int.max
            return (idx1 == idx2) ? (key1 < key2) : (idx1 < idx2)
        }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(sortedKeys, id: \.self) { key in
                    let sorted = groupedNewsletters[key]?.sorted(by: { $0.newsletterDate > $1.newsletterDate }) ?? []
                    HistoricalGroupSectionView(
                        groupKey: key,
                        newsletters: sorted,
                        expandedGroup: $expandedGroup,
                        selectedNewsletter: $selectedNewsletter,
                        showingActionSheet: $showingActionSheet,
                        isNavigating: $isNavigating,
                        toggleReadStatus: toggleReadStatus
                    )
                }
            }
            .actionSheet(isPresented: $showingActionSheet) {
                ActionSheet(
                    title: Text("Actions"),
                    buttons: [
                        .default(Text((selectedNewsletter?.isRead ?? false) ? "Mark as Unread" : "Mark as Read")) {
                            if let newsletter = selectedNewsletter {
                                toggleReadStatus(newsletter)
                            }
                        },
                        .cancel()
                    ]
                )
            }
            .navigationTitle("Newsletters")
        }
    }

    private func toggleReadStatus(_ newsletter: NewsletterMetadata) {
        guard let docId = newsletter.id else { return }
        let db = Firestore.firestore()
        let newValue = !(newsletter.isRead ?? false)

        db.collection("NewsletterMetadata").document(docId).updateData([
            "isRead": newValue
        ]) { error in
            if error == nil {
                if let index = viewModel.newsletters.firstIndex(where: { $0.id == newsletter.id }) {
                    viewModel.newsletters[index].isRead = newValue
                }
            }
        }
    }
}

// MARK: - Group Section View

struct HistoricalGroupSectionView: View {
    let groupKey: String
    let newsletters: [NewsletterMetadata]

    @Binding var expandedGroup: String?
    @Binding var selectedNewsletter: NewsletterMetadata?
    @Binding var showingActionSheet: Bool
    @Binding var isNavigating: Bool

    let toggleReadStatus: (NewsletterMetadata) -> Void

    var body: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedGroup == groupKey },
                set: { expandedGroup = $0 ? groupKey : nil }
            ),
            content: {
                ForEach(newsletters) { newsletter in
                    ZStack {
                        NavigationLink(
                            destination: NewsletterReaderView(newsletter: newsletter),
                            isActive: Binding(
                                get: { selectedNewsletter?.id == newsletter.id && isNavigating },
                                set: { if !$0 { isNavigating = false }}
                            )
                        ) {
                            EmptyView()
                        }.opacity(0)

                        HistoricalNewsletterViewRow(
                            newsletter: newsletter,
                            onTap: {
                                if newsletter.isRead != true {
                                    toggleReadStatus(newsletter)
                                }
                                selectedNewsletter = newsletter
                                isNavigating = true
                            },
                            onLongPress: {
                                selectedNewsletter = newsletter
                                showingActionSheet = true
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        )
                    }
                }
            },
            label: {
                Text(groupKey).font(.headline)
            }
        )
    }
}

// MARK: - Newsletter Row View

struct HistoricalNewsletterViewRow: View {
    let newsletter: NewsletterMetadata
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(newsletter.vendorName)
                    .font(.headline)
                    .foregroundColor((newsletter.isRead ?? false) ? .gray : .primary)
                Text(newsletter.subject)
                    .font(.subheadline)
                    .foregroundColor((newsletter.isRead ?? false) ? .gray : .primary)
                Text(formattedDate(newsletter.newsletterDate))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.leading, 20)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: 0.4, perform: onLongPress)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Grouping Extension

extension Array where Element == NewsletterMetadata {
    func groupedForHistorical() -> [String: [NewsletterMetadata]] {
        var groups = [String: [NewsletterMetadata]]()
        let nytKeywords = ["The Morning", "Breaking News", "The Evening", "Climate"]

        for newsletter in self {
            let sender = newsletter.vendorName
            let subject = newsletter.subject
            let key: String

            if sender == "The New York Times" {
                if let keyword = nytKeywords.first(where: { subject.range(of: $0, options: .caseInsensitive) != nil }) {
                    key = "The New York Times: \(keyword)"
                } else {
                    key = "The New York Times: Other"
                }
            } else if sender.contains("Morning Brew") {
                key = "Morning Brew"
            } else if sender.contains("Tech Brew") {
                key = "Tech Brew"
            } else if sender.contains("IT Brew") {
                key = "IT Brew"
            } else if sender.contains("Sigma Xi") {
                key = "Sigma Xi"
            } else if sender.contains("HEATED") {
                key = "HEATED"
            } else {
                key = sender
            }

            groups[key, default: []].append(newsletter)
        }

        return groups
    }
}
