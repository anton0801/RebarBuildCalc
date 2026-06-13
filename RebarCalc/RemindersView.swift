//
//  RemindersView.swift
//  RebarCalc
//
//  Screen 17 — reminders. Order steel, check tying & cover, call for the
//  hidden-works inspection. Real UNUserNotificationCenter scheduling.
//

import SwiftUI

struct RemindersView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var notifications: NotificationManager
    @State private var showAdd = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Space.m) {
                    if !notifications.authorized { authCard }
                    PrimaryButton(title: "Add reminder", systemImage: "plus") {
                        if !notifications.authorized {
                            notifications.requestAuthorization { _ in }
                        }
                        showAdd = true
                    }

                    if store.reminders.isEmpty {
                        Card { EmptyState(icon: "bell.slash", title: "No reminders", message: "Schedule a steel order or a pre-pour check.") }
                    } else {
                        ForEach(store.reminders) { reminder in
                            reminderCard(reminder)
                        }
                    }
                }
                .padding(Theme.Space.m)
                .padding(.bottom, 30)
            }
        }
        .navigationBarTitle("Reminders", displayMode: .inline)
        .onAppear { notifications.refreshStatus() }
        .sheet(isPresented: $showAdd) {
            AddReminderSheet { reminder in store.addReminder(reminder) }
        }
    }

    private var authCard: some View {
        Card(glow: Theme.attention.opacity(0.3)) {
            HStack(spacing: 12) {
                Image(systemName: "bell.slash.fill").font(.system(size: 20)).foregroundColor(Theme.attention)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications off").font(Theme.heading(14)).foregroundColor(Theme.text)
                    Text("Allow notifications to get reminders.").font(Theme.caption(12)).foregroundColor(Theme.textSecond)
                }
                Spacer()
                Button("Allow") { notifications.requestAuthorization { _ in } }
                    .font(Theme.heading(14)).foregroundColor(Theme.primary)
            }
        }
    }

    private func reminderCard(_ reminder: Reminder) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: reminder.kind.icon).font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.attention).frame(width: 38, height: 38)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.attention.opacity(0.15)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reminder.title).font(Theme.heading(15)).foregroundColor(Theme.text).lineLimit(2)
                        Text(Fmt.dateTime(reminder.date)).font(Theme.caption(12)).foregroundColor(Theme.textMuted)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { reminder.enabled },
                        set: { var r = reminder; r.enabled = $0; store.updateReminder(r) }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Theme.primary))
                }
                if reminder.date < Date() {
                    StatusBadge(text: "Past", color: Theme.textMuted, icon: "clock.badge.xmark")
                }
                HStack {
                    Spacer()
                    Button(action: { Haptic.warning(); store.deleteReminder(reminder) }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash").font(.system(size: 12))
                            Text("Delete").font(Theme.caption(13))
                        }.foregroundColor(Theme.error)
                    }
                }
            }
        }
    }
}

// MARK: - Add reminder sheet

struct AddReminderSheet: View {
    @Environment(\.presentationMode) private var presentationMode
    let onSave: (Reminder) -> Void

    @State private var kind: ReminderKind = .orderSteel
    @State private var title: String = ReminderKind.orderSteel.detail
    @State private var date: Date = Date().addingTimeInterval(3600)

    var body: some View {
        NavigationView {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Space.l) {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Type", systemImage: "bell.fill")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(ReminderKind.allCases) { k in
                                        Chip(title: k.rawValue, systemImage: k.icon, selected: kind == k, accent: Theme.attention) {
                                            kind = k
                                            title = k.detail
                                        }
                                    }
                                }
                            }
                        }
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Note").font(Theme.caption(11)).tracking(0.6).foregroundColor(Theme.textMuted)
                                ThemedTextField(placeholder: "Reminder text", text: $title)
                            }
                        }
                        Card {
                            DatePicker("When", selection: $date, in: Date()...)
                                .datePickerStyle(CompactDatePickerStyle())
                                .accentColor(Theme.primary)
                                .foregroundColor(Theme.text)
                        }
                    }
                    .padding(Theme.Space.m)
                }
            }
            .navigationBarTitle("New Reminder", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() }.foregroundColor(Theme.textSecond),
                trailing: Button("Save") {
                    let r = Reminder(kind: kind, title: title.isEmpty ? kind.detail : title, date: date)
                    onSave(r)
                    Haptic.success()
                    presentationMode.wrappedValue.dismiss()
                }.foregroundColor(Theme.primary)
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
