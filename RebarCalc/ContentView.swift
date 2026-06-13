//
//  ContentView.swift
//  RebarCalc
//
//  Root state machine: Splash → (first launch) Onboarding → Main app.
//

import SwiftUI

enum AppPhase { case splash, onboarding, main }

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var phase: AppPhase = .splash

    var body: some View {
        ZStack {
            switch phase {
            case .splash:
                SplashView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        phase = hasCompletedOnboarding ? .main : .onboarding
                    }
                }
                .transition(.opacity)

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
    }
}
