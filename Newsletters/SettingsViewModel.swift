//
//  SettingsViewModel.swift
//  Newsletters
//
//  Created by Palmer Nix on 3/17/26.
//

import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

class SettingsViewModel: ObservableObject {
    @Published var enabledNewsletters: Set<String> = []
    @Published var notificationNewsletters: Set<String> = []
    @Published var sectionOrder: [String] = UserDefaults.standard.stringArray(forKey: "digestSectionOrder") ?? []

    /// Reference to the newsletter store, set by MainView after creation.
    /// When the store finishes loading, we notify observers so views re-evaluate shouldShow().
    var newsletterStore: NewsletterStore? {
        didSet { observeStore() }
    }
    private var storeCancellable: AnyCancellable?

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

    private func observeStore() {
        storeCancellable = newsletterStore?.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

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

                // Migrate legacy email-based prefs to sender IDs if needed
                if let self, self.migrateEmailsToSenderIds(data) {
                    return // Migration wrote new data; listener will fire again
                }

                let notifications = data["notificationNewsletters"] as? [String] ?? []
                DispatchQueue.main.async {
                    self?.enabledNewsletters = Set(enabled)
                    self?.notificationNewsletters = Set(notifications)
                }
            }
    }

    private func seedSettings(userId: String) {
        let allIds = newsletterStore?.newsletters.map { $0.id } ?? []
        let data: [String: Any] = ["enabledNewsletters": allIds]
        db.collection("users").document(userId)
            .collection("settings").document("preferences")
            .setData(data)
    }

    /// Detects legacy email-based prefs (containing @) and converts to sender IDs.
    /// Returns true if migration was performed (caller should skip normal assignment).
    private func migrateEmailsToSenderIds(_ data: [String: Any]) -> Bool {
        guard let enabled = data["enabledNewsletters"] as? [String],
              enabled.contains(where: { $0.contains("@") }),
              let store = newsletterStore else { return false }

        let migratedEnabled: Set<String> = Set(store.newsletters.filter { nl in
            nl.emails.contains(where: { email in enabled.contains(email) })
        }.map { $0.id })

        let notifications = data["notificationNewsletters"] as? [String] ?? []
        let migratedNotifications: Set<String> = Set(store.newsletters.filter { nl in
            nl.emails.contains(where: { email in notifications.contains(email) })
        }.map { $0.id })

        enabledNewsletters = migratedEnabled
        notificationNewsletters = migratedNotifications
        saveToFirestore()
        return true
    }

    func toggle(_ newsletter: NewsletterInfo) {
        if isEnabled(newsletter) {
            enabledNewsletters.remove(newsletter.id)
            notificationNewsletters.remove(newsletter.id)
        } else {
            enabledNewsletters.insert(newsletter.id)
        }
        saveToFirestore()
    }

    func isEnabled(_ newsletter: NewsletterInfo) -> Bool {
        enabledNewsletters.contains(newsletter.id)
    }

    /// Check if a newsletter metadata item should be shown based on its sender.
    /// Shows all newsletters while the store is still loading.
    func shouldShow(_ metadata: NewsletterMetadata) -> Bool {
        guard let store = newsletterStore, store.isLoaded else { return true }
        guard let nl = store.from(sender: metadata.sender) else { return false }
        return enabledNewsletters.contains(nl.id)
    }

    /// Writes the full list of all sender emails to Firestore so AppsScript can read it.
    func syncSenderFilters() {
        guard let store = newsletterStore else { return }
        let data: [String: Any] = [
            "senderEmails": store.allSenderEmails
        ]

        db.collection("Settings").document("senderFilters").setData(data) { error in
            if let error = error {
                print("Error syncing sender filters: \(error.localizedDescription)")
            }
        }
    }

    func isNotificationEnabled(_ newsletter: NewsletterInfo) -> Bool {
        notificationNewsletters.contains(newsletter.id)
    }

    func toggleNotification(_ newsletter: NewsletterInfo) {
        if isNotificationEnabled(newsletter) {
            notificationNewsletters.remove(newsletter.id)
        } else {
            notificationNewsletters.insert(newsletter.id)
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
