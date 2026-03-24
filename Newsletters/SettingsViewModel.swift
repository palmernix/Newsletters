//
//  SettingsViewModel.swift
//  Newsletters
//
//  Created by Palmer Nix on 3/17/26.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class SettingsViewModel: ObservableObject {
    @Published var enabledNewsletters: Set<String> = Set(Newsletter.allSenderEmails)
    @Published var notificationNewsletters: Set<String> = []
    @Published var sectionOrder: [String] = UserDefaults.standard.stringArray(forKey: "digestSectionOrder") ?? []

    private static let defaultSections = [
        "Business & Finance", "Startups & Venture Capital", "Artificial Intelligence",
        "US Politics", "World Politics", "Healthcare", "Science", "Technology",
        "Climate & Environment", "Culture & Entertainment", "Sports", "Other"
    ]

    func fetchDigestCategories() {
        db.collection("Config").document("digestCategories").getDocument { [weak self] snapshot, error in
            guard let self else { return }
            let sections = (snapshot?.data()?["sections"] as? [String]) ?? Self.defaultSections
            DispatchQueue.main.async { self.mergeSectionOrder(canonical: sections) }
        }
    }

    private func mergeSectionOrder(canonical: [String]) {
        let stored = UserDefaults.standard.stringArray(forKey: "digestSectionOrder") ?? []
        let ordered = stored.filter { canonical.contains($0) }
        let missing = canonical.filter { !ordered.contains($0) }
        sectionOrder = ordered + missing
    }

    func moveSections(from: IndexSet, to: Int) {
        sectionOrder.move(fromOffsets: from, toOffset: to)
        UserDefaults.standard.set(sectionOrder, forKey: "digestSectionOrder")
    }

    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var userId: String? { Auth.auth().currentUser?.uid }

    func fetchSettings() {
        guard let userId else { return }
        listener = db.collection("users").document(userId)
            .collection("settings").document("preferences")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error { print("Error fetching settings: \(error)"); return }
                guard let data = snapshot?.data(),
                      let enabled = data["enabledNewsletters"] as? [String] else {
                    // No doc yet — seed with all newsletters enabled
                    self?.seedSettings(userId: userId)
                    return
                }
                let notifications = data["notificationNewsletters"] as? [String] ?? []
                DispatchQueue.main.async {
                    self?.enabledNewsletters = Set(enabled)
                    self?.notificationNewsletters = Set(notifications)
                }
            }
    }

    private func seedSettings(userId: String) {
        let data: [String: Any] = ["enabledNewsletters": Newsletter.allSenderEmails]
        db.collection("users").document(userId)
            .collection("settings").document("preferences")
            .setData(data)
    }

    func toggle(_ newsletter: Newsletter) {
        if isEnabled(newsletter) {
            newsletter.senderEmails.forEach { enabledNewsletters.remove($0) }
            // Auto-disable notifications when newsletter is turned off
            newsletter.senderEmails.forEach { notificationNewsletters.remove($0) }
        } else {
            newsletter.senderEmails.forEach { enabledNewsletters.insert($0) }
        }
        saveToFirestore()
    }

    func isEnabled(_ newsletter: Newsletter) -> Bool {
        newsletter.senderEmails.contains { enabledNewsletters.contains($0) }
    }

    /// Check if a newsletter metadata item should be shown based on its sender
    func shouldShow(_ metadata: NewsletterMetadata) -> Bool {
        // Extract email from "Name <email@domain>" or use full string
        let sender = metadata.sender.lowercased()
        return enabledNewsletters.contains { sender.contains($0.lowercased()) }
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

    func isNotificationEnabled(_ newsletter: Newsletter) -> Bool {
        newsletter.senderEmails.contains { notificationNewsletters.contains($0) }
    }

    func toggleNotification(_ newsletter: Newsletter) {
        if isNotificationEnabled(newsletter) {
            newsletter.senderEmails.forEach { notificationNewsletters.remove($0) }
        } else {
            newsletter.senderEmails.forEach { notificationNewsletters.insert($0) }
        }
        saveToFirestore()
    }

    private func saveToFirestore() {
        guard let userId else { return }
        let data: [String: Any] = [
            "enabledNewsletters": Array(enabledNewsletters),
            "notificationNewsletters": Array(notificationNewsletters)
        ]
        db.collection("users").document(userId)
            .collection("settings").document("preferences")
            .setData(data, merge: true) { error in
                if let error = error { print("Error saving settings: \(error)") }
            }
    }
}
