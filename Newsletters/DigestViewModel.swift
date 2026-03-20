//
//  DigestViewModel.swift
//  Newsletters
//
//  Created by Palmer Nix on 3/17/26.
//

import SwiftUI
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth

// MARK: - Data Models

struct DigestSource: Codable {
    let newsletterId: String
    let displayName: String
}

struct DigestItem: Codable {
    let headline: String
    let description: String
    let sources: [DigestSource]
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
    @Published var refreshAvailable = false

    private var db = Firestore.firestore()
    private var functions = Functions.functions()

    func checkAndGenerate(
        todayNewsletters: [NewsletterMetadata],
        enabledEmails: Set<String>
    ) {
        // If already loaded, just check whether new newsletters have arrived
        if case .loaded(let current) = state {
            refreshAvailable = hasNewNewsletters(storedIds: current.newsletterIds, todayNewsletters: todayNewsletters, enabledEmails: enabledEmails)
            return
        }
        // Don't interrupt an in-progress generation
        if case .loading = state { return }

        guard let userId = Auth.auth().currentUser?.uid else { return }

        let todayItems = todayNewsletters.filter {
            Calendar.current.isDateInToday($0.newsletterDate)
        }
        if todayItems.isEmpty {
            state = .empty(.noNewslettersToday)
            return
        }

        let anyEnabled = todayItems.contains { meta in
            let sender = meta.sender.lowercased()
            return enabledEmails.contains { sender.contains($0.lowercased()) }
        }
        if !anyEnabled {
            state = .empty(.noneEnabled)
            return
        }

        let today = ISO8601DateFormatter.localDateString()
        let digestRef = db.collection("users").document(userId)
            .collection("digests").document(today)

        state = .loading

        digestRef.getDocument { [weak self] snapshot, error in
            guard let self else { return }

            if let data = snapshot?.data(), let cached = DigestDocument(from: data) {
                DispatchQueue.main.async {
                    self.state = .loaded(cached)
                    self.refreshAvailable = self.hasNewNewsletters(storedIds: cached.newsletterIds, todayNewsletters: todayItems, enabledEmails: enabledEmails)
                }
                return
            }

            // No cache — generate automatically
            self.generate(userId: userId, staleDigest: nil)
        }
    }

    func refresh(todayNewsletters: [NewsletterMetadata], enabledEmails: Set<String>) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let staleDigest: DigestDocument? = { if case .loaded(let d) = state { return d }; return nil }()
        refreshAvailable = false
        state = .loading
        generate(userId: userId, staleDigest: staleDigest)
    }

    private func hasNewNewsletters(
        storedIds: [String],
        todayNewsletters: [NewsletterMetadata],
        enabledEmails: Set<String>
    ) -> Bool {
        let currentIds = Set(todayNewsletters
            .filter { Calendar.current.isDateInToday($0.newsletterDate) }
            .filter { meta in
                let sender = meta.sender.lowercased()
                return enabledEmails.contains { sender.contains($0.lowercased()) }
            }
            .compactMap { $0.id })
        return !currentIds.isSubset(of: Set(storedIds))
    }

    private func generate(userId: String, staleDigest: DigestDocument?) {
        let callable = functions.httpsCallable("generateDigest")
        callable.timeoutInterval = 300
        callable.call([:]) { [weak self] result, error in
            guard let self else { return }
            if let error = error {
                print("Digest generation error: \(error)")
                DispatchQueue.main.async { self.state = .error(staleDigest: staleDigest) }
                return
            }
            guard let data = result?.data as? [String: Any],
                  let digest = DigestDocument(from: data) else {
                DispatchQueue.main.async { self.state = .error(staleDigest: staleDigest) }
                return
            }
            DispatchQueue.main.async { self.state = .loaded(digest) }
        }
    }
}

// MARK: - DigestDocument init from [String: Any]

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
            let items: [DigestItem] = itemsData.compactMap { itemDict in
                guard let headline = itemDict["headline"] as? String,
                      let description = itemDict["description"] as? String,
                      let sourcesData = itemDict["sources"] as? [[String: Any]] else { return nil }
                let sources: [DigestSource] = sourcesData.compactMap { srcDict in
                    guard let id = srcDict["newsletterId"] as? String,
                          let name = srcDict["displayName"] as? String else { return nil }
                    return DigestSource(newsletterId: id, displayName: name)
                }
                return DigestItem(headline: headline, description: description, sources: sources)
            }
            return DigestSection(title: title, items: items)
        }

        self.generatedAt = generatedAt
        self.newsletterCount = data["newsletterCount"] as? Int ?? 0
        self.newsletterIds = data["newsletterIds"] as? [String] ?? []
        self.sections = sections
    }
}

private extension ISO8601DateFormatter {
    static func localDateString() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.string(from: Date())
    }
}
