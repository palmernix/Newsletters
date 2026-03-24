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
    var scrollToAnchor: String? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: HTMLWebView

        init(_ parent: HTMLWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let anchor = parent.scrollToAnchor else { return }
            let js = "document.getElementById('\(anchor)')?.scrollIntoView({behavior:'smooth'});"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
