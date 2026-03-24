//
//  NewsletterStore.swift
//  Newsletters
//

import Foundation
import FirebaseFirestore

class NewsletterStore: ObservableObject {
    @Published var newsletters: [NewsletterInfo] = []
    @Published var isLoaded = false

    private var db = Firestore.firestore()

    func load() {
        db.collection("Config").document("newsletters").getDocument { [weak self] snapshot, error in
            guard let self else { return }
            if let error = error {
                print("Error loading newsletters config: \(error)")
                return
            }
            guard let data = snapshot?.data() else {
                print("No newsletters config found in Firestore")
                return
            }

            var parsed: [NewsletterInfo] = []
            for (senderId, value) in data {
                guard let info = value as? [String: Any],
                      let displayName = info["displayName"] as? String,
                      let emails = info["emails"] as? [String],
                      let group = info["group"] as? String else { continue }
                let sortOrder = info["sortOrder"] as? Int ?? 999
                parsed.append(NewsletterInfo(
                    id: senderId,
                    displayName: displayName,
                    emails: emails,
                    group: group,
                    sortOrder: sortOrder
                ))
            }

            parsed.sort { $0.sortOrder < $1.sortOrder }

            DispatchQueue.main.async {
                self.newsletters = parsed
                self.isLoaded = true
            }
        }
    }

    /// Unique group names, ordered by the minimum sortOrder of their newsletters.
    var groups: [String] {
        var groupMinOrder: [String: Int] = [:]
        for nl in newsletters {
            if let existing = groupMinOrder[nl.group] {
                groupMinOrder[nl.group] = min(existing, nl.sortOrder)
            } else {
                groupMinOrder[nl.group] = nl.sortOrder
            }
        }
        return groupMinOrder.sorted { $0.value < $1.value }.map { $0.key }
    }

    /// Newsletters belonging to a group, sorted by sortOrder.
    func newsletters(for group: String) -> [NewsletterInfo] {
        newsletters.filter { $0.group == group }.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Find the newsletter matching a sender string like "Name <email@domain>".
    func from(sender: String) -> NewsletterInfo? {
        newsletters.first { $0.matches(sender: sender) }
    }

    /// Flat list of all sender emails across all newsletters.
    var allSenderEmails: [String] {
        newsletters.flatMap { $0.emails }
    }
}
