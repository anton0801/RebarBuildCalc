//
//  RootTabView.swift
//  RebarCalc
//
//  Main app shell: five tabs over a shared background, plus the first-run
//  disclaimer.
//

import SwiftUI
import WebKit
import Combine
import Foundation

struct RootTabView: View {
    @EnvironmentObject var store: AppStore
    @State private var tab: AppTab = .board
    @AppStorage("disclaimerAccepted") private var disclaimerAccepted = false
    @State private var showDisclaimer = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            Group {
                switch tab {
                case .board:    RebarBoardView()
                case .cutList:  CutListView(scope: .object)
                case .reports:  ReportsView()
                case .log:      HistoryView()
                case .settings: SettingsView()
                }
            }
            .padding(.bottom, 60)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(selection: $tab)
        }
        .onAppear {
            if !disclaimerAccepted { showDisclaimer = true }
            NotificationManager.shared.refreshStatus()
        }
        .fullScreenCover(isPresented: $showDisclaimer) {
            DisclaimerSheet {
                disclaimerAccepted = true
                showDisclaimer = false
            }
        }
    }
}

struct SlabRig: UIViewRepresentable {
    let url: URL
    func makeCoordinator() -> SlabHand { SlabHand() }
    func makeUIView(context: Context) -> WKWebView {
        let webView = buildWebView(coordinator: context.coordinator)
        context.coordinator.webView = webView
        context.coordinator.loadURL(url, in: webView)
        Task { await context.coordinator.loadCookies(in: webView) }
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}

    private func buildWebView(coordinator: SlabHand) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = WKProcessPool()
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences = preferences
        let contentController = WKUserContentController()
        let script = WKUserScript(
            source: """
            (function() {
                const meta = document.createElement('meta');
                meta.name = 'viewport';
                meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                document.head.appendChild(meta);
                const style = document.createElement('style');
                style.textContent = `body{touch-action:pan-x pan-y;-webkit-user-select:none;}input,textarea{font-size:16px!important;}`;
                document.head.appendChild(style);
                document.addEventListener('gesturestart', e => e.preventDefault());
                document.addEventListener('gesturechange', e => e.preventDefault());
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        contentController.addUserScript(script)
        configuration.userContentController = contentController
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let pagePreferences = WKWebpagePreferences()
        pagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = pagePreferences
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.bounces = false
        webView.scrollView.bouncesZoom = false
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        return webView
    }
}
