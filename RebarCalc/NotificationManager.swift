//
//  NotificationManager.swift
//  RebarCalc
//
//  Thin wrapper over UNUserNotificationCenter for the reminder feature.
//

import UserNotifications
import SwiftUI
import Foundation

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var authorized: Bool = false

    private init() { refreshStatus() }

    func refreshStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorized = settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
            }
        }
    }

    func requestAuthorization(_ completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                DispatchQueue.main.async {
                    self.authorized = granted
                    completion?(granted)
                }
            }
    }

    func newRequestAuthorization(_ completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                DispatchQueue.main.async {
                    completion?(granted)
                }
            }
    }

    /// Schedules a one-off reminder keyed by its UUID so it can be cancelled later.
    func schedule(_ reminder: Reminder) {
        guard reminder.date > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = reminder.kind.rawValue
        content.body = reminder.title
        content.sound = .default

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: reminder.date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: reminder.id.uuidString,
                                            content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func cancel(_ reminder: Reminder) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Re-syncs all enabled, future reminders (used after edits / app launch).
    func sync(_ reminders: [Reminder]) {
        cancelAll()
        for r in reminders where r.enabled && r.date > Date() { schedule(r) }
    }
}

protocol Cinch {
    func draw() async -> Bool
    func armChime()
}

final class TieCinch: Cinch {

    private let center = UNUserNotificationCenter.current()

    func draw() async -> Bool {
        let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            center.requestAuthorization(options: [.alert, .badge, .sound]) { ok, _ in
                cont.resume(returning: ok)
            }
        }
        if granted { armChime() }
        return granted
    }

    func armChime() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}
