//
//  SampleData.swift
//  RebarCalc
//
//  Populated first-launch object so the app never opens empty.
//

import Foundation

enum SampleData {
    static func make() -> AppData {
        let settings = ProjectSettings()

        let footing = RebarElement(
            name: "Perimeter footing",
            type: .stripFooting,
            length: 14.4, width: 0.6, sectionB: 600, sectionH: 400, cover: 40,
            mainDia: 12, mainSpacing: 200, mainCount: 4,
            transDia: 8, transSpacing: 300, layers: 1, lapDiameters: 40, endHooks: true,
            notes: "Continuous strip under load-bearing walls."
        )

        let slab = RebarElement(
            name: "Ground-floor slab",
            type: .slab,
            length: 6.2, width: 4.4, sectionB: 1000, sectionH: 200, cover: 30,
            mainDia: 12, mainSpacing: 200, mainCount: 0,
            transDia: 10, transSpacing: 200, layers: 2, lapDiameters: 40,
            notes: "Two-way mesh, top and bottom."
        )

        let column = RebarElement(
            name: "Column C1",
            type: .column,
            length: 3.0, width: 0.4, sectionB: 400, sectionH: 400, cover: 35,
            mainDia: 16, mainSpacing: 200, mainCount: 4,
            transDia: 8, transSpacing: 200, layers: 1, lapDiameters: 45,
            notes: "Corner column."
        )

        let beam = RebarElement(
            name: "Beam B2",
            type: .beam,
            length: 6.0, width: 0.3, sectionB: 300, sectionH: 500, cover: 30,
            mainDia: 16, mainSpacing: 200, mainCount: 4,
            transDia: 8, transSpacing: 200, layers: 1, lapDiameters: 40
        )

        let history: [HistoryEvent] = [
            HistoryEvent(kind: .added, message: "Added “Perimeter footing”", date: Date().addingTimeInterval(-86400 * 3)),
            HistoryEvent(kind: .added, message: "Added “Ground-floor slab”", date: Date().addingTimeInterval(-86400 * 2)),
            HistoryEvent(kind: .laidOut, message: "Laid out “Ground-floor slab”", date: Date().addingTimeInterval(-86400)),
            HistoryEvent(kind: .cutListed, message: "Cut list ready for the object", date: Date().addingTimeInterval(-3600))
        ]

        let reminders: [Reminder] = [
            Reminder(kind: .orderSteel, title: "Order steel per the schedule",
                     date: Date().addingTimeInterval(86400)),
            Reminder(kind: .checkTying, title: "Check tying & cover before pour",
                     date: Date().addingTimeInterval(86400 * 2))
        ]

        return AppData(elements: [footing, slab, column, beam],
                       settings: settings,
                       reminders: reminders,
                       history: history)
    }
}

enum BarKey {
    static let routeURL = "rbc_route_url"
    static let routeMode = "rbc_route_mode"
    static let primed = "rbc_primed"
    static let cinchGiven = "rbc_cinch_given"
    static let cinchBarred = "rbc_cinch_barred"
    static let cinchAt = "rbc_cinch_at"
    static let pushURL = "temp_url"
    static let fcm = "fcm_token"
    static let push = "push_token"
    static let attStatus = "att_status"
    static let sharedFcm = "shared_fcm"
}

extension Notification.Name {
    static let barsArrived = Notification.Name("ConversionDataReceived")
    static let lapsArrived = Notification.Name("deeplink_values")
    static let pourWake = Notification.Name("LoadTempURL")
}
