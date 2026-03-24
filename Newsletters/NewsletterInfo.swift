//
//  NewsletterInfo.swift
//  Newsletters
//

import Foundation

struct NewsletterInfo: Identifiable {
    let id: String          // sender ID, e.g. "morningBrew"
    let displayName: String
    let emails: [String]
    let group: String
    let sortOrder: Int

    /// Check if this newsletter matches a sender string like "Name <email@domain>"
    func matches(sender: String) -> Bool {
        let lowered = sender.lowercased()
        return emails.contains { lowered.contains($0.lowercased()) }
    }
}
