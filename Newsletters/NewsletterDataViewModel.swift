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
    /// When `preferAnchored` is true, uses `anchoredBody` (with section anchors) if available.
    func fetchData(newsletterId: String, preferAnchored: Bool = false) {
        guard !newsletterId.isEmpty else {
            self.content = "No newsletter ID provided."
            self.isLoading = false
            return
        }

        db.collection("NewsletterData").document(newsletterId).getDocument { document, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.content = "Error loading content: \(error.localizedDescription)"
                } else if let document = document, document.exists, let data = document.data() {
                    if preferAnchored, let anchored = data["anchoredBody"] as? String, !anchored.isEmpty {
                        self.content = anchored
                    } else if let body = data["body"] as? String {
                        self.content = body
                    } else {
                        self.content = "No content available."
                    }
                } else {
                    self.content = "No content available."
                }
                self.isLoading = false
            }
        }
    }
}
