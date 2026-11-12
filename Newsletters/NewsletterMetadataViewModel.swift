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

/// Fetches newsletter metadata from Firestore in two tiers so the Today tab
/// never waits on the full history:
///  - today's newsletters are listened to as soon as `fetchMetadata()` is called
///  - everything older is listened to only once something asks for it via
///    `loadHistoricalIfNeeded()` (the Historical tab).
/// `newsletters` always exposes the union of both tiers.
class NewsletterMetadataViewModel: ObservableObject {
    /// Today's newsletters followed by historical ones (once loaded).
    @Published var newsletters: [NewsletterMetadata] = []
    /// False until the first snapshot of today's newsletters has arrived.
    @Published var hasLoadedToday = false
    /// True while the first historical snapshot is being fetched and decoded.
    @Published private(set) var isLoadingHistorical = false
    /// False until the first historical snapshot has finished loading.
    @Published private(set) var hasLoadedHistorical = false
    /// A user-displayable error from the historical listener, if one occurs.
    @Published private(set) var historicalLoadError: String?

    private var db = Firestore.firestore()
    private var todayListener: ListenerRegistration?
    private var historicalListener: ListenerRegistration?
    private var todayItems: [NewsletterMetadata] = []
    private var historicalItems: [NewsletterMetadata] = []
    private var dayChangeObserver: NSObjectProtocol?
    private let metadataDecodingQueue = DispatchQueue(
        label: "com.palmernix.the-edition.metadata-decoding",
        qos: .userInitiated
    )

    private var startOfToday: Date { Calendar.current.startOfDay(for: Date()) }

    init() {
        // The query boundaries are fixed when a listener is created, so re-create
        // them at midnight to keep "today" and "historical" partitioned correctly.
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.restartListeners()
        }
    }

    deinit {
        todayListener?.remove()
        historicalListener?.remove()
        dayChangeObserver.map { NotificationCenter.default.removeObserver($0) }
    }

    /// Starts listening to today's newsletters only.
    func fetchMetadata() {
        todayListener?.remove()
        let startedAt = Date()
        print("Setting up Firestore listener for today's metadata.")

        todayListener = db.collection("NewsletterMetadata")
            .whereField("newsletterDate", isGreaterThanOrEqualTo: startOfToday)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let items = Self.decode(snapshot, error, label: "today") else { return }
                let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
                let source = snapshot?.metadata.isFromCache == true ? "cache" : "server"
                print("[today] \(items.count) newsletters from \(source) in \(elapsedMs)ms")
                self.todayItems = items
                self.hasLoadedToday = true
                self.recompose()
            }
    }

    /// Starts listening to newsletters older than today. Safe to call repeatedly.
    func loadHistoricalIfNeeded() {
        guard historicalListener == nil else { return }
        let startedAt = Date()
        isLoadingHistorical = true
        historicalLoadError = nil
        print("Setting up Firestore listener for historical metadata.")

        historicalListener = db.collection("NewsletterMetadata")
            .whereField("newsletterDate", isLessThan: startOfToday)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    DispatchQueue.main.async {
                        self.isLoadingHistorical = false
                        self.hasLoadedHistorical = true
                        self.historicalLoadError = error.localizedDescription
                    }
                    return
                }
                guard let snapshot else {
                    DispatchQueue.main.async {
                        self.isLoadingHistorical = false
                        self.hasLoadedHistorical = true
                        self.historicalLoadError = "No historical newsletters were returned."
                    }
                    return
                }

                let documents = snapshot.documents
                let source = snapshot.metadata.isFromCache ? "cache" : "server"
                self.metadataDecodingQueue.async { [weak self] in
                    let items = Self.decode(documents, label: "historical")
                    let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)

                    DispatchQueue.main.async {
                        guard let self else { return }
                        print("[historical] \(items.count) newsletters from \(source) in \(elapsedMs)ms")
                        self.historicalItems = items
                        self.isLoadingHistorical = false
                        self.hasLoadedHistorical = true
                        self.historicalLoadError = nil
                        self.recompose()
                    }
                }
            }
    }

    func refresh() {
        restartListeners()
    }

    private func restartListeners() {
        let wasListeningToHistorical = historicalListener != nil
        historicalListener?.remove()
        historicalListener = nil
        fetchMetadata()
        if wasListeningToHistorical {
            loadHistoricalIfNeeded()
        }
    }

    private func recompose() {
        newsletters = todayItems + historicalItems
    }

    /// Decodes a snapshot, skipping (and logging) any document that fails to decode
    /// so one bad document can't blank the whole list. Returns nil on a query error.
    private static func decode(_ snapshot: QuerySnapshot?, _ error: Error?, label: String) -> [NewsletterMetadata]? {
        if let error {
            print("[\(label)] Error fetching metadata: \(error)")
            return nil
        }
        guard let documents = snapshot?.documents else {
            print("[\(label)] No documents in snapshot")
            return nil
        }
        return decode(documents, label: label)
    }

    private static func decode(_ documents: [QueryDocumentSnapshot], label: String) -> [NewsletterMetadata] {
        documents.compactMap { doc in
            do {
                return try doc.data(as: NewsletterMetadata.self)
            } catch {
                print("[\(label)] Skipping undecodable document \(doc.documentID): \(error)")
                return nil
            }
        }
    }
}
