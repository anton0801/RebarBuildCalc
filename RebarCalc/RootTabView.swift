//
//  RootTabView.swift
//  RebarCalc
//
//  Main app shell: five tabs over a shared background, plus the first-run
//  disclaimer.
//

import SwiftUI

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
