//
//  SettingsViewModel.swift
//  Newsletters
//
//  Created by Palmer Nix on 3/17/26.
//

import SwiftUI
import FirebaseFirestore

class SettingsViewModel: ObservableObject {
    @Published var enabledNewsletters: Set<String> = Set(Newsletter.allCases.map { $0.rawValue })

    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let documentId = "userPreferences"

    func fetchSettings() {
        listener = db.collection("Settings").document(documentId)
            .addSnapshotListener { [weak self] (snapshot, error) in
                if let error = error {
                    print("Error fetching settings: \(error)")
                    return
                }

                guard let data = snapshot?.data(),
                      let enabled = data["enabledNewsletters"] as? [String] else {
                    // No settings doc yet — default to all enabled
                    return
                }

                DispatchQueue.main.async {
                    self?.enabledNewsletters = Set(enabled)
                }
            }
    }

    func toggle(_ newsletter: Newsletter) {
        if enabledNewsletters.contains(newsletter.rawValue) {
            enabledNewsletters.remove(newsletter.rawValue)
        } else {
            enabledNewsletters.insert(newsletter.rawValue)
        }
        saveToFirestore()
    }

    func isEnabled(_ newsletter: Newsletter) -> Bool {
        enabledNewsletters.contains(newsletter.rawValue)
    }

    /// Check if a newsletter metadata item should be shown based on its sender
    func shouldShow(_ metadata: NewsletterMetadata) -> Bool {
        guard let newsletter = Newsletter.from(sender: metadata.sender) else {
            return true // Show unknown senders by default
        }
        return enabledNewsletters.contains(newsletter.rawValue)
    }

    /// Writes the full list of all sender emails to Firestore so AppsScript can read it.
    /// Called on launch so the list stays in sync with the Newsletter enum.
    func syncSenderFilters() {
        let data: [String: Any] = [
            "senderEmails": Newsletter.allSenderEmails
        ]

        db.collection("Settings").document("senderFilters").setData(data) { error in
            if let error = error {
                print("Error syncing sender filters: \(error.localizedDescription)")
            }
        }
    }

    private func saveToFirestore() {
        let data: [String: Any] = [
            "enabledNewsletters": Array(enabledNewsletters)
        ]

        db.collection("Settings").document(documentId).setData(data) { error in
            if let error = error {
                print("Error saving settings: \(error.localizedDescription)")
            }
        }
    }
}
