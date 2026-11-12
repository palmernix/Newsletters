//
//  NewslettersTests.swift
//  NewslettersTests
//
//  Created by Palmer Nix on 4/3/25.
//

import Foundation
import Testing
@testable import Newsletters

struct NewslettersTests {

    @Test func appBrandingPreservesIdentity() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "The Edition")
        #expect(Bundle.main.bundleIdentifier == "com.palmernix.Newsletters")
        #expect(Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil)
    }

}
