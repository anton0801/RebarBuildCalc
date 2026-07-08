//
//  CustomTabBar.swift
//  RebarCalc
//
//  The styled bottom navigation for the main app shell.
//

import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case board, cutList, reports, log, settings
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .board: return "Board"
        case .cutList: return "Cut List"
        case .reports: return "Reports"
        case .log: return "Log"
        case .settings: return "Settings"
        }
    }
    var icon: String {
        switch self {
        case .board: return "square.grid.3x3.fill"
        case .cutList: return "scissors"
        case .reports: return "doc.text.fill"
        case .log: return "clock.arrow.circlepath"
        case .settings: return "gearshape.fill"
        }
    }
    var iconsNew: String {
        switch self {
        case .board: return "square.grid.3x3"
        case .cutList: return "scissors"
        case .reports: return "doc.text"
        case .log: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(
            Theme.bgDeep
                .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        return Button(action: {
            Haptic.select()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { selection = tab }
        }) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Circle().fill(Theme.primary.opacity(0.18)).frame(width: 38, height: 38)
                    }
                    Image(systemName: tab.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(isSelected ? Theme.primary : Theme.textMuted)
                        .shadow(color: isSelected ? Theme.blueGlow : .clear, radius: 6)
                }
                .frame(height: 38)
                Text(tab.title)
                    .font(Theme.caption(10))
                    .foregroundColor(isSelected ? Theme.primary : Theme.textMuted)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
