//
//  RebarCalcApp.swift
//  RebarCalc
//
//  App entry point. Injects the shared store + notification manager, applies the
//  persisted appearance, flushes on background and styles global UIKit chrome.
//

import SwiftUI

// MARK: - Appearance

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@main
struct RebarCalcApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var notifications = NotificationManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearanceRaw = AppAppearance.dark.rawValue

    private var appearance: AppAppearance { AppAppearance(rawValue: appearanceRaw) ?? .dark }

    init() { Self.configureGlobalAppearance() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(notifications)
                .preferredColorScheme(appearance.colorScheme)
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { store.flush() }
            if phase == .active { notifications.refreshStatus() }
        }
    }

    private static func configureGlobalAppearance() {
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = UIColor(hex: 0x080F19, alpha: 0.85)
        nav.titleTextAttributes = [.foregroundColor: UIColor(hex: 0xE9F1FE)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(hex: 0xE9F1FE)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(hex: 0x2D70EA)
    }
}
