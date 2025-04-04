//
//  HTMLWebView.swift
//  Newsletters
//
//  Created by Palmer Nix on 4/3/25.
//

import SwiftUI
import WebKit

struct HTMLWebView: UIViewRepresentable {
    let htmlContent: String

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
}
