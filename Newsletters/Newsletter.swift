//
//  Newsletter.swift
//  Newsletters
//
//  Created by Palmer Nix on 3/17/26.
//

import Foundation

enum NewsletterGroup: String, CaseIterable {
    case morningBrew = "Morning Brew"
    case newYorkTimes = "The New York Times"
    case sigmaXi = "Sigma Xi"
    case heated = "HEATED"
    case historyFacts = "History Facts"
    case evolvingAI = "Evolving AI"
    case ceoReport = "The CEO Report"
}

enum Newsletter: String, CaseIterable, Identifiable {
    case morningBrew
    case techBrew
    case itBrew
    case nytTheMorning
    case nytBreakingNews
    case sigmaXiSmartBrief
    case heated
    case historyFacts
    case evolvingAI
    case ceoReport

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morningBrew: return "Morning Brew Daily"
        case .techBrew: return "Tech Brew"
        case .itBrew: return "IT Brew"
        case .nytTheMorning: return "New York Times The Morning"
        case .nytBreakingNews: return "New York Times Breaking News"
        case .sigmaXiSmartBrief: return "Sigma Xi SmartBrief"
        case .heated: return "HEATED"
        case .historyFacts: return "History Facts Daily"
        case .evolvingAI: return "Evolving AI"
        case .ceoReport: return "The CEO Report"
        }
    }

    var senderEmails: [String] {
        switch self {
        case .morningBrew: return ["crew@morningbrew.com"]
        case .techBrew: return ["techbrew@morningbrew.com"]
        case .itBrew: return ["itbrew@morningbrew.com"]
        case .nytTheMorning: return ["nytdirect@nytimes.com"]
        case .nytBreakingNews: return ["breakingnews@nytimes.com", "breakingnews-noreply@nytimes.com"]
        case .sigmaXiSmartBrief: return ["sigmaxi@smartbrief.com"]
        case .heated: return ["heated@substack.com"]
        case .historyFacts: return ["hello@historyfacts.com"]
        case .evolvingAI: return ["hello.evolvingai@gmail.com"]
        case .ceoReport: return ["max@marketingmax.io"]
        }
    }

    var group: NewsletterGroup {
        switch self {
        case .morningBrew, .techBrew, .itBrew: return .morningBrew
        case .nytTheMorning, .nytBreakingNews: return .newYorkTimes
        case .sigmaXiSmartBrief: return .sigmaXi
        case .heated: return .heated
        case .historyFacts: return .historyFacts
        case .evolvingAI: return .evolvingAI
        case .ceoReport: return .ceoReport
        }
    }

    static func newsletters(for group: NewsletterGroup) -> [Newsletter] {
        allCases.filter { $0.group == group }
    }

    /// All sender emails across all newsletters (for AppsScript scraping)
    static var allSenderEmails: [String] {
        allCases.flatMap { $0.senderEmails }
    }

    /// Find the Newsletter that matches a given sender email string.
    /// The sender field from Firestore looks like "Name <email@example.com>"
    static func from(sender: String) -> Newsletter? {
        let lowered = sender.lowercased()
        return allCases.first { newsletter in
            newsletter.senderEmails.contains { email in
                lowered.contains(email)
            }
        }
    }
}
