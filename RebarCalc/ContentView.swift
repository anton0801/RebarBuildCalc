import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var notifications: NotificationManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var phase: AppPhase = .main
    
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearanceRaw = AppAppearance.dark.rawValue
    private var appearance: AppAppearance { AppAppearance(rawValue: appearanceRaw) ?? .dark }
    
    init() { Self.configureGlobalAppearance() }
    
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

    var body: some View {
        ZStack {
            switch phase {
            case .onboarding:
                OnboardingView {
                    hasCompletedOnboarding = true
                    store.resyncReminders()
                    withAnimation(.easeInOut(duration: 0.5)) { phase = .main }
                }
                .transition(.opacity)

            case .main:
                RootTabView()
                    .transition(.opacity)
                    .onAppear { store.resyncReminders() }
            }
        }
        .onAppear {
            if !hasCompletedOnboarding {
                phase = .main
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .onChange(of: scenePhase) { phases in
            if phases != .active { store.flush() }
            if phases == .active { notifications.refreshStatus() }
        }
    }
}
