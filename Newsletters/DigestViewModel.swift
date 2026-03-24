//
//  DigestViewModel.swift
//  Newsletters
//
//  Created by Palmer Nix on 3/17/26.
//

import SwiftUI
import FirebaseFirestore
import FirebaseFunctions

// MARK: - Data Models

struct DigestSource: Codable {
    let newsletterId: String
    let displayName: String
    let senderId: String?
    let sectionIndex: Int?
}

struct StoryImage: Codable {
    let url: String
    let newsletterId: String
}

struct DigestItem: Codable {
    let headline: String
    let description: String
    let sources: [DigestSource]
    let storyId: String?
    let magnitude: Double?
    let images: [StoryImage]?
}

struct DigestSection: Codable {
    let title: String
    let items: [DigestItem]
}

struct DigestDocument {
    let generatedAt: Date
    let newsletterCount: Int
    let newsletterIds: [String]
    let sections: [DigestSection]
    let topStories: [DigestItem]?
}

enum EmptyReason {
    case noNewslettersToday
    case noneEnabled
}

enum DigestState {
    case idle
    case loading
    case loaded(DigestDocument)
    case empty(EmptyReason)
    case error(staleDigest: DigestDocument?)
}

// MARK: - ViewModel

class DigestViewModel: ObservableObject {
    @Published var state: DigestState = .idle

    private var functions = Functions.functions()

    /// Reference to the newsletter store, set by MainView after creation.
    var newsletterStore: NewsletterStore?

    func loadDigest(
        todayNewsletters: [NewsletterMetadata],
        enabledSenders: Set<String>
    ) {
        // Don't interrupt an in-progress generation
        if case .loading = state { return }

        let todayItems = todayNewsletters.filter {
            Calendar.current.isDateInToday($0.newsletterDate)
        }
        if todayItems.isEmpty {
            state = .empty(.noNewslettersToday)
            return
        }

        let anyEnabled = todayItems.contains { meta in
            guard let nl = newsletterStore?.from(sender: meta.sender) else { return false }
            return enabledSenders.contains(nl.id)
        }
        if !anyEnabled {
            state = .empty(.noneEnabled)
            return
        }

        state = .loading
        generate()
    }

    private func generate() {
        let callable = functions.httpsCallable("generateDigest")
        callable.timeoutInterval = 300
        callable.call([:]) { [weak self] result, error in
            guard let self else { return }
            if let error = error {
                print("Digest generation error: \(error)")
                DispatchQueue.main.async { self.state = .error(staleDigest: nil) }
                return
            }
            guard let data = result?.data as? [String: Any],
                  let digest = DigestDocument(from: data) else {
                DispatchQueue.main.async { self.state = .error(staleDigest: nil) }
                return
            }
            DispatchQueue.main.async { self.state = .loaded(digest) }
        }
    }
}

// MARK: - DigestDocument init from [String: Any]

private func parseDigestItem(from itemDict: [String: Any]) -> DigestItem? {
    guard let headline = itemDict["headline"] as? String,
          let description = itemDict["description"] as? String,
          let sourcesData = itemDict["sources"] as? [[String: Any]] else { return nil }

    let sources: [DigestSource] = sourcesData.compactMap { srcDict in
        guard let id = srcDict["newsletterId"] as? String,
              let name = srcDict["displayName"] as? String else { return nil }
        return DigestSource(
            newsletterId: id,
            displayName: name,
            senderId: srcDict["senderId"] as? String,
            sectionIndex: srcDict["sectionIndex"] as? Int
        )
    }

    let images: [StoryImage]? = (itemDict["images"] as? [[String: Any]])?.compactMap { imgDict in
        guard let url = imgDict["url"] as? String,
              let nlId = imgDict["newsletterId"] as? String else { return nil }
        return StoryImage(url: url, newsletterId: nlId)
    }

    return DigestItem(
        headline: headline,
        description: description,
        sources: sources,
        storyId: itemDict["storyId"] as? String,
        magnitude: itemDict["magnitude"] as? Double,
        images: images
    )
}

private extension DigestDocument {
    init?(from data: [String: Any]) {
        guard let sectionsData = data["sections"] as? [[String: Any]] else { return nil }

        // Parse generatedAt — either ISO8601 string (from CF response) or Firestore Timestamp
        var generatedAt = Date.distantPast
        if let iso = data["generatedAt"] as? String,
           let date = ISO8601DateFormatter().date(from: iso) {
            generatedAt = date
        } else if let ts = data["generatedAt"] as? Timestamp {
            generatedAt = ts.dateValue()
        }

        let sections: [DigestSection] = sectionsData.compactMap { sectionDict in
            guard let title = sectionDict["title"] as? String,
                  let itemsData = sectionDict["items"] as? [[String: Any]] else { return nil }
            let items: [DigestItem] = itemsData.compactMap { parseDigestItem(from: $0) }
            return DigestSection(title: title, items: items)
        }

        let topStories: [DigestItem]? = (data["topStories"] as? [[String: Any]])?.compactMap {
            parseDigestItem(from: $0)
        }

        self.generatedAt = generatedAt
        self.newsletterCount = data["newsletterCount"] as? Int ?? 0
        self.newsletterIds = data["newsletterIds"] as? [String] ?? []
        self.sections = sections
        self.topStories = topStories
    }
}
