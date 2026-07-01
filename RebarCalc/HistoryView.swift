//
//  HistoryView.swift
//  RebarCalc
//
//  Screen 16 — history feed: element added / laid out / cut-listed / tied /
//  pour-ready and other events.
//

import SwiftUI

enum Snag: Error {
    case barren(at: String)
    case skewSpan(at: String)
    case torn(stage: String)
    case choked(cooldown: TimeInterval)
    case gridDown(httpCode: Int)
    case shortPour(reason: String)
    case deformed(at: String)

    var isSealed: Bool {
        switch self {
        case .gridDown, .shortPour:
            return true
        default:
            return false
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject var store: AppStore
    @State private var showClear = false

    var body: some View {
        NavigationView {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Space.m) {
                        NavigationLink(destination: RemindersView()) {
                            remindersBanner
                        }.buttonStyle(PlainButtonStyle())

                        SectionHeader(title: "Activity", systemImage: "clock.arrow.circlepath")

                        if store.history.isEmpty {
                            Card { EmptyState(icon: "clock", title: "No activity yet", message: "Adding and laying out elements will show up here.") }
                        } else {
                            Card {
                                VStack(spacing: 0) {
                                    ForEach(store.history) { event in
                                        eventRow(event)
                                        if event.id != store.history.last?.id {
                                            Divider().background(Theme.border.opacity(0.5))
                                        }
                                    }
                                }
                            }
                            SecondaryButton(title: "Clear history", systemImage: "trash") { showClear = true }
                        }
                    }
                    .padding(Theme.Space.m)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitle("Log", displayMode: .inline)
            .alert(isPresented: $showClear) {
                Alert(title: Text("Clear history?"),
                      message: Text("This removes the activity feed. Your elements stay."),
                      primaryButton: .destructive(Text("Clear")) { store.clearHistory() },
                      secondaryButton: .cancel())
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var remindersBanner: some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge.fill").font(.system(size: 20)).foregroundColor(Theme.attention)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reminders").font(Theme.heading(15)).foregroundColor(Theme.text)
                    Text("\(store.reminders.filter { $0.enabled }.count) active").font(Theme.caption(12)).foregroundColor(Theme.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.textMuted)
            }
        }
    }

    private func eventRow(_ event: HistoryEvent) -> some View {
        let color = Color(hex: event.kind.color)
        return HStack(spacing: 12) {
            Image(systemName: event.kind.icon).font(.system(size: 14, weight: .semibold))
                .foregroundColor(color).frame(width: 34, height: 34)
                .background(Circle().fill(color.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(event.message).font(Theme.body(14)).foregroundColor(Theme.text).lineLimit(2)
                Text(Fmt.dateTime(event.date)).font(Theme.caption(11)).foregroundColor(Theme.textMuted)
            }
            Spacer()
        }
        .padding(.vertical, 9)
    }
}
