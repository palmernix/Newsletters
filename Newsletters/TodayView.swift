import SwiftUI
import FirebaseFirestore

struct TodayView: View {
    @ObservedObject var viewModel: NewsletterMetadataViewModel

    @State private var selectedNewsletter: NewsletterMetadata?
    @State private var showingActionSheet = false
    @State private var isNavigating = false

    var body: some View {
        let todayNewsletters = viewModel.newsletters.filter { isToday($0.newsletterDate) }
        let groups = todayNewsletters.groupedForToday()
        let customOrder = ["The New York Times", "Morning Brew", "Sigma Xi", "HEATED"]
        let sortedKeys = groups.keys.sorted {
            let i1 = customOrder.firstIndex(of: $0) ?? Int.max
            let i2 = customOrder.firstIndex(of: $1) ?? Int.max
            return i1 == i2 ? $0 < $1 : i1 < i2
        }

        NavigationView {
            List {
                if todayNewsletters.isEmpty {
                    Text("No newsletters received yet today!")
                        .foregroundColor(.gray)
                        .italic()
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(sortedKeys, id: \.self) { key in
                        Section(header: Text(key)) {
                            let sortedNewsletters = sortedNewsletters(for: key, newsletters: groups[key] ?? [])
                            ForEach(sortedNewsletters) { newsletter in
                                NewsletterMetadataRow(
                                    newsletter: newsletter,
                                    isSelected: selectedNewsletter?.id == newsletter.id,
                                    isNavigating: $isNavigating,
                                    onTap: {
                                        if newsletter.isRead != true {
                                            toggleReadStatus(for: newsletter)
                                        }
                                        selectedNewsletter = newsletter
                                        isNavigating = true
                                    },
                                    onLongPress: {
                                        selectedNewsletter = newsletter
                                        showingActionSheet = true
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .actionSheet(isPresented: $showingActionSheet) {
                ActionSheet(
                    title: Text("Actions"),
                    buttons: [
                        .default(Text((selectedNewsletter?.isRead ?? false) ? "Mark as Unread" : "Mark as Read")) {
                            if let selected = selectedNewsletter {
                                toggleReadStatus(for: selected)
                            }
                        },
                        .cancel()
                    ]
                )
            }
            .navigationTitle("Newsletters")
        }
    }

    func toggleReadStatus(for newsletter: NewsletterMetadata) {
        guard let docId = newsletter.id else { return }
        let newValue = !(newsletter.isRead ?? false)
        let db = Firestore.firestore()

        db.collection("NewsletterMetadata").document(docId).updateData([
            "isRead": newValue
        ]) { error in
            if let error = error {
                print("⚠️ Failed to update isRead: \(error.localizedDescription)")
            } else {
                print("✅ isRead updated to \(newValue) for \(docId)")
            }
        }
    }

    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    func sortedNewsletters(for groupKey: String, newsletters: [NewsletterMetadata]) -> [NewsletterMetadata] {
        if groupKey == "The New York Times" {
            let nytOrder = ["The Morning", "The Evening", "Breaking News", "Climate"]
            return newsletters.sorted { n1, n2 in
                let idx1 = nytOrder.firstIndex(where: { keyword in
                    n1.subject.range(of: keyword, options: .caseInsensitive) != nil
                }) ?? Int.max
                let idx2 = nytOrder.firstIndex(where: { keyword in
                    n2.subject.range(of: keyword, options: .caseInsensitive) != nil
                }) ?? Int.max
                return idx1 < idx2
            }
        } else if groupKey == "Morning Brew" {
            let order = ["Morning Brew", "Emerging Tech Brew", "IT Brew"]
            return newsletters.sorted {
                let i1 = order.firstIndex(of: $0.vendorName) ?? Int.max
                let i2 = order.firstIndex(of: $1.vendorName) ?? Int.max
                return i1 < i2
            }
        } else {
            return newsletters.sorted { $0.newsletterDate > $1.newsletterDate }
        }
    }
}

struct NewsletterMetadataRow: View {
    let newsletter: NewsletterMetadata
    let isSelected: Bool
    @Binding var isNavigating: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        ZStack {
            NavigationLink(
                destination: NewsletterReaderView(newsletter: newsletter),
                isActive: Binding(
                    get: { isSelected && isNavigating },
                    set: { if !$0 { isNavigating = false } }
                )
            ) {
                EmptyView()
            }
            .opacity(0)

            VStack(alignment: .leading, spacing: 4) {
                if newsletter.vendorName == "The New York Times" {
                    let parsed = parseNYTSubject(newsletter.subject)
                    Text(parsed.0)
                        .font(.headline)
                        .foregroundColor((newsletter.isRead ?? false) ? .gray : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(parsed.1)
                        .font(.subheadline)
                        .foregroundColor((newsletter.isRead ?? false) ? .gray : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(newsletter.vendorName)
                        .font(.headline)
                        .foregroundColor((newsletter.isRead ?? false) ? .gray : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(newsletter.subject)
                        .font(.subheadline)
                        .foregroundColor((newsletter.isRead ?? false) ? .gray : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .onLongPressGesture(minimumDuration: 0.2) {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                onLongPress()
            }
        }
    }

    private func parseNYTSubject(_ subject: String) -> (String, String) {
        let keywords = ["The Morning", "Breaking News", "The Evening", "Climate"]
        for keyword in keywords {
            if let range = subject.range(of: keyword, options: .caseInsensitive) {
                let headline = keyword.capitalizedWords()
                var remainder = subject[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                remainder = remainder.trimmingCharacters(in: CharacterSet(charactersIn: ":- "))
                return (headline, remainder)
            }
        }
        return ("The New York Times", subject)
    }
}

// MARK: - Extensions

extension Array where Element == NewsletterMetadata {
    func groupedForToday() -> [String: [NewsletterMetadata]] {
        var groups: [String: [NewsletterMetadata]] = [:]
        for newsletter in self {
            let key: String
            if newsletter.vendorName == "The New York Times" {
                key = "The New York Times"
            } else if ["Morning Brew", "IT Brew", "Tech Brew"].contains(newsletter.vendorName) {
                key = "Morning Brew"
            } else if newsletter.vendorName.contains("Sigma Xi") {
                key = "Sigma Xi"
            } else if newsletter.vendorName.contains("HEATED") {
                key = "HEATED"
            } else {
                key = newsletter.vendorName
            }
            groups[key, default: []].append(newsletter)
        }
        return groups
    }
}

extension String {
    func capitalizedWords() -> String {
        self.split(separator: " ").map { $0.capitalized }.joined(separator: " ")
    }
}

extension String {
    func caseInsensitiveCompare(in text: String) -> Bool {
        text.range(of: self, options: .caseInsensitive) != nil
    }
}
