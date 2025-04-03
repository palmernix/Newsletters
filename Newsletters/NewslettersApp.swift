//
//  NewslettersApp.swift
//  Newsletters
//
//  Created by Palmer Nix on 4/3/25.
//

import SwiftUI
import Firebase

@main
struct NewslettersApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
