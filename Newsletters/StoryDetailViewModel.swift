//
//  StoryDetailViewModel.swift
//  Newsletters
//

import Foundation
import FirebaseFirestore

class StoryDetailViewModel: ObservableObject {

    struct SourceClipping: Identifiable {
        let id: String  // newsletterId
        let displayName: String
        let senderId: String?
        let sectionIndex: Int
        let htmlClipping: String
        let newsletterMetadata: NewsletterMetadata?
    }

    @Published var clippings: [SourceClipping] = []
    @Published var isLoading = true

    private var db = Firestore.firestore()

    func fetchClippings(for item: DigestItem, allMetadata: [NewsletterMetadata]) {
        let sourcesWithSection = item.sources.filter { $0.sectionIndex != nil }
        if sourcesWithSection.isEmpty {
            DispatchQueue.main.async { self.isLoading = false }
            return
        }

        let group = DispatchGroup()
        var results: [SourceClipping] = []
        let lock = NSLock()

        for source in sourcesWithSection {
            guard let sectionIndex = source.sectionIndex else { continue }
            group.enter()

            db.collection("NewsletterData").document(source.newsletterId).getDocument { snapshot, error in
                defer { group.leave() }

                guard let data = snapshot?.data() else { return }

                // Prefer anchoredBody, fall back to body
                let html = data["anchoredBody"] as? String ?? data["body"] as? String ?? ""
                guard !html.isEmpty else { return }

                let clippingHtml = Self.extractClipping(from: html, sectionIndex: sectionIndex)
                guard let clippingHtml, !clippingHtml.isEmpty else { return }

                let metadata = allMetadata.first { $0.id == source.newsletterId }

                let clipping = SourceClipping(
                    id: source.newsletterId,
                    displayName: source.displayName,
                    senderId: source.senderId,
                    sectionIndex: sectionIndex,
                    htmlClipping: clippingHtml,
                    newsletterMetadata: metadata
                )

                lock.lock()
                results.append(clipping)
                lock.unlock()
            }
        }

        group.notify(queue: .main) {
            // Sort by the order sources appear in the item
            let sourceOrder = sourcesWithSection.map { $0.newsletterId }
            self.clippings = results.sorted { a, b in
                let ai = sourceOrder.firstIndex(of: a.id) ?? Int.max
                let bi = sourceOrder.firstIndex(of: b.id) ?? Int.max
                return ai < bi
            }
            self.isLoading = false
        }
    }

    /// Extract the HTML between section-N and section-(N+1) anchors.
    static func extractClipping(from anchoredBody: String, sectionIndex: Int) -> String? {
        let startMarker = "id=\"section-\(sectionIndex)\""
        guard let startRange = anchoredBody.range(of: startMarker) else { return nil }

        let nextMarker = "id=\"section-\(sectionIndex + 1)\""
        if let endRange = anchoredBody.range(of: nextMarker, range: startRange.lowerBound..<anchoredBody.endIndex) {
            // Back up to the opening <a tag
            let searchRange = startRange.lowerBound..<endRange.lowerBound
            if let tagStart = anchoredBody.range(of: "<a ", options: .backwards, range: searchRange) {
                return String(anchoredBody[startRange.lowerBound..<tagStart.lowerBound])
            }
            return String(anchoredBody[startRange.lowerBound..<endRange.lowerBound])
        }

        // Last section — take everything from start anchor to end
        return String(anchoredBody[startRange.lowerBound...])
    }
}
