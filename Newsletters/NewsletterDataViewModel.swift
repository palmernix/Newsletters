//
//  NewsletterDataViewModel.swift
//  Newsletters
//
//  Created by Palmer Nix on 4/3/25.
//

import Foundation
import FirebaseFirestore

class NewsletterDataViewModel: ObservableObject {
    @Published var content: String = ""
    @Published var isLoading: Bool = true
    
    private var db = Firestore.firestore()
    
    /// Fetches the newsletter data from the "NewsletterData" collection by newsletter id.
    func fetchData(newsletterId: String) {
        guard !newsletterId.isEmpty else {
            self.content = "No newsletter ID provided."
            self.isLoading = false
            return
        }
        
        // Assuming your collection is called "NewsletterData" and each document's id matches the newsletter's id.
        db.collection("NewsletterData").document(newsletterId).getDocument { document, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.content = "Error loading content: \(error.localizedDescription)"
                } else if let document = document, document.exists,
                          let data = document.data(), let fullBody = data["body"] as? String {
                    self.content = fullBody
                } else {
                    self.content = "No content available."
                }
                self.isLoading = false
            }
        }
    }
}
