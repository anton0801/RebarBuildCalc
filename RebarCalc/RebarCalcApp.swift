//
//  RebarCalcApp.swift
//  RebarCalc
//
//  App entry point. Injects the shared store + notification manager, applies the
//  persisted appearance, flushes on background and styles global UIKit chrome.
//

import SwiftUI

// MARK: - Appearance

enum Bar {
    static let appCode = "6783286065"
    static let millEndpoint = "https://rebarbuildcalc.com/config.php"
    static let caliperKey = "WGW2CsNZd4wu5p7vz96xHg"
    static let suiteBay = "group.rebarbuildcalc.bay"
    static let cookieDeck = "rebarbuildcalc_deck"
    static let ledgerFile = "rbc_lattice_ledger.json"
    static let bayVault = "RebarBay"
}

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

enum AppPhase { case onboarding, main }

@main
struct RebarCalcApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegator
    @StateObject private var store = AppStore()
    @StateObject private var notifications = NotificationManager.shared
    

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(store)
                .environmentObject(notifications)
        }
    }
    
}


final class Tamp {

    func tamp(_ payload: [AnyHashable: Any]) {
        var flat: [String: Any] = [:]

        func walk(_ node: [AnyHashable: Any], _ prefix: String) {
            for (key, value) in node {
                let path = prefix.isEmpty ? "\(key)" : "\(prefix).\(key)"
                if let child = value as? [AnyHashable: Any] {
                    walk(child, path)
                } else {
                    flat[path] = value
                }
            }
        }

        walk(payload, "")

        let routes = ["url", "data.url", "aps.data.url", "custom.url"]
        guard let url = routes.lazy.compactMap({ flat[$0] as? String }).first(where: { !$0.isEmpty }) else { return }

        UserDefaults.standard.set(url, forKey: BarKey.pushURL)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            NotificationCenter.default.post(
                name: .pourWake,
                object: nil,
                userInfo: ["temp_url": url]
            )
        }
    }
}
