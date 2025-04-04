//
//  NewsletterViewModel.swift
//  Newsletters
//
//  Created by Palmer Nix on 4/3/25.
//

import SwiftUI
import FirebaseFirestore

struct NewsletterMetadata: Identifiable, Codable {
    @DocumentID var id: String?
    var sender: String
    var newsletterDate: Date
    var subject: String
    var content: String?
    var isRead: Bool?

    var vendorName: String {
        // Look for the first occurrence of "<" in the sender string.
        if let range = sender.range(of: "<") {
            // Extract the substring before "<" and trim any whitespace.
            return String(sender[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // If "<" is not found, return the entire sender.
        return sender
    }
}

// Create a view model that fetches data from Firestore.
class NewsletterMetadataViewModel: ObservableObject {
    @Published var newsletters: [NewsletterMetadata] = []
    
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    func fetchMetadata() {
        print("Setting up Firestore metadata snapshot listener.")

        listener = db.collection("NewsletterMetadata")
            .addSnapshotListener { [weak self] (querySnapshot, error) in
                if let error = error {
                    print("Error fetching metadata: \(error)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("[fetchData] No documents in snapshot: \(error?.localizedDescription ?? "No error")")
                    return
                }

                print("[fetchData] Number of documents returned: \(documents.count)")
                
                // For deeper debugging, you could log each document ID or partial data:
                // documents.forEach { doc in print("[fetchData] docID: \(doc.documentID), data: \(doc.data())") }

                do {
                    // Attempt to decode ALL documents, throwing an error on the first failure.
                    let fetchedNewsletters = try documents.map { doc -> NewsletterMetadata in
                        try doc.data(as: NewsletterMetadata.self)
                    }
                    
                    DispatchQueue.main.async {
                        self?.newsletters = fetchedNewsletters
                        print("Fetched \(fetchedNewsletters.count) newsletters")
                    }
                } catch {
                    // If ANY document fails to decode, we catch the error here.
                    print("Error decoding documents: \(error)")
                }
        }
    }
    
    func refresh() {
        fetchMetadata()
    }
}
