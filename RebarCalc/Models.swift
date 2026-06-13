//
//  Models.swift
//  RebarCalc
//
//  All persisted Codable value types and the enums that drive the app.
//

import SwiftUI

// MARK: - Element type

enum ElementType: String, Codable, CaseIterable, Identifiable {
    case stripFooting = "Strip footing"
    case slab         = "Slab"
    case column       = "Column"
    case beam         = "Beam"
    case gradeBeam    = "Grade beam"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .stripFooting: return "rectangle.compress.vertical"
        case .slab:         return "square.grid.3x3.fill"
        case .column:       return "cylinder.fill"
        case .beam:         return "rectangle.fill"
        case .gradeBeam:    return "rectangle.split.3x1.fill"
        }
    }

    var short: String {
        switch self {
        case .stripFooting: return "Footing"
        case .slab:         return "Slab"
        case .column:       return "Column"
        case .beam:         return "Beam"
        case .gradeBeam:    return "Grade beam"
        }
    }

    /// Planar elements use a two-way mesh laid out by spacing in both directions.
    /// Linear elements use an explicit number of longitudinal bars plus stirrups/ties.
    var isPlanar: Bool { self == .slab }

    /// Linear elements (beams, columns, footings) carry stirrups/ties.
    var hasStirrups: Bool { !isPlanar }

    /// Default geometry seeded into a new element form.
    var defaults: ElementDefaults {
        switch self {
        case .stripFooting: return ElementDefaults(length: 12, width: 0.6, b: 600, h: 400, mainDia: 12, mainCount: 4, transDia: 8, mainSpacing: 200, transSpacing: 300, layers: 1)
        case .slab:         return ElementDefaults(length: 6, width: 4, b: 1000, h: 200, mainDia: 12, mainCount: 0, transDia: 10, mainSpacing: 200, transSpacing: 200, layers: 2)
        case .column:       return ElementDefaults(length: 3, width: 0.4, b: 400, h: 400, mainDia: 16, mainCount: 4, transDia: 8, mainSpacing: 200, transSpacing: 200, layers: 1)
        case .beam:         return ElementDefaults(length: 6, width: 0.3, b: 300, h: 500, mainDia: 16, mainCount: 4, transDia: 8, mainSpacing: 200, transSpacing: 200, layers: 1)
        case .gradeBeam:    return ElementDefaults(length: 8, width: 0.3, b: 300, h: 450, mainDia: 14, mainCount: 4, transDia: 8, mainSpacing: 200, transSpacing: 250, layers: 1)
        }
    }
}

struct ElementDefaults {
    var length: Double      // m
    var width: Double       // m (plan width — planar only)
    var b: Double           // mm (section width)
    var h: Double           // mm (section height / thickness)
    var mainDia: Int
    var mainCount: Int
    var transDia: Int
    var mainSpacing: Double // mm
    var transSpacing: Double// mm
    var layers: Int
}

// MARK: - Common bar diameters (mm)

enum BarSize {
    static let all: [Int] = [8, 10, 12, 14, 16, 20, 25, 32]
    static let onboarding: [Int] = [8, 10, 12, 14, 16]

    /// Nominal mass per metre (kg/m) by the classic d²/162 rule.
    static func kgPerMeter(_ dia: Int) -> Double {
        Double(dia * dia) / 162.0
    }

    /// Cross-sectional area of one bar (mm²).
    static func area(_ dia: Int) -> Double {
        Double.pi * Double(dia) * Double(dia) / 4.0
    }
}

// MARK: - Pre-pour checklist

struct PrePourChecklist: Codable, Equatable {
    var coverHeld: Bool = false
    var lapsInPlace: Bool = false
    var stirrupsTied: Bool = false
    var startersSet: Bool = false

    var allDone: Bool { coverHeld && lapsInPlace && stirrupsTied && startersSet }
    var doneCount: Int { [coverHeld, lapsInPlace, stirrupsTied, startersSet].filter { $0 }.count }
}

// MARK: - Rebar element

struct RebarElement: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var type: ElementType

    // Length dimensions in metres.
    var length: Double      // span / height / footing length / slab length
    var width: Double       // slab / footing plan width

    // Section dimensions in millimetres.
    var sectionB: Double    // width
    var sectionH: Double    // height / thickness

    var cover: Double       // mm

    // Main longitudinal reinforcement.
    var mainDia: Int
    var mainSpacing: Double // mm (planar)
    var mainCount: Int      // explicit count (linear)

    // Transverse / stirrups.
    var transDia: Int
    var transSpacing: Double// mm

    var layers: Int         // 1 = single mesh, 2 = top + bottom
    var lapDiameters: Double// lap length as a multiple of bar diameter
    var endHooks: Bool      // add L-hooks to longitudinal bar ends

    var notes: String
    var photoFile: String?
    var checklist: PrePourChecklist
    var pourReady: Bool
    var createdAt: Date

    init(id: UUID = UUID(),
         name: String,
         type: ElementType,
         length: Double,
         width: Double,
         sectionB: Double,
         sectionH: Double,
         cover: Double,
         mainDia: Int,
         mainSpacing: Double,
         mainCount: Int,
         transDia: Int,
         transSpacing: Double,
         layers: Int,
         lapDiameters: Double,
         endHooks: Bool = false,
         notes: String = "",
         photoFile: String? = nil,
         checklist: PrePourChecklist = PrePourChecklist(),
         pourReady: Bool = false,
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.type = type
        self.length = length
        self.width = width
        self.sectionB = sectionB
        self.sectionH = sectionH
        self.cover = cover
        self.mainDia = mainDia
        self.mainSpacing = mainSpacing
        self.mainCount = mainCount
        self.transDia = transDia
        self.transSpacing = transSpacing
        self.layers = layers
        self.lapDiameters = lapDiameters
        self.endHooks = endHooks
        self.notes = notes
        self.photoFile = photoFile
        self.checklist = checklist
        self.pourReady = pourReady
        self.createdAt = createdAt
    }

    static func blank(type: ElementType, settings: ProjectSettings) -> RebarElement {
        let d = type.defaults
        return RebarElement(
            name: type.short + " " + String(Int.random(in: 1...99)),
            type: type,
            length: d.length,
            width: d.width,
            sectionB: d.b,
            sectionH: d.h,
            cover: settings.defaultCover,
            mainDia: d.mainDia,
            mainSpacing: d.mainSpacing,
            mainCount: d.mainCount,
            transDia: d.transDia,
            transSpacing: d.transSpacing,
            layers: d.layers,
            lapDiameters: settings.defaultLapDia
        )
    }
}

// MARK: - Project settings (engineering defaults, persisted in JSON)

struct ProjectSettings: Codable, Equatable {
    var stockLength: Double = 11.7      // m — standard delivered bar length
    var defaultLapDia: Double = 40      // lap = N × diameter
    var defaultCover: Double = 30       // mm
    var steelPrice: Double = 0.95       // currency per kg
    var tieWirePerTonne: Double = 12    // kg of tie wire per tonne of steel
    var tieWirePrice: Double = 2.4      // currency per kg of wire
    var spacerSpacing: Double = 0.6     // m grid for chair spacers
    var spacerPrice: Double = 0.25      // currency per spacer
    var laborPerTonne: Double = 140     // currency per tonne tied
    var hookFactor: Double = 10         // hook length = N × diameter
    var minHook: Double = 75            // mm — minimum hook leg

    /// Optional user overrides of the bar-weight table, keyed by diameter (mm) as string.
    var barWeightOverrides: [String: Double] = [:]

    func kgPerMeter(_ dia: Int) -> Double {
        if let override = barWeightOverrides[String(dia)] { return override }
        return BarSize.kgPerMeter(dia)
    }
}

// MARK: - Reminders

enum ReminderKind: String, Codable, CaseIterable, Identifiable {
    case orderSteel  = "Order steel"
    case checkTying  = "Check tying"
    case inspection  = "Hidden-works call"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .orderSteel: return "shippingbox.fill"
        case .checkTying: return "checkmark.seal.fill"
        case .inspection: return "phone.fill"
        }
    }
    var detail: String {
        switch self {
        case .orderSteel: return "Order the steel by the bar schedule."
        case .checkTying: return "Check tying & cover before the pour."
        case .inspection: return "Call for the hidden-works inspection."
        }
    }
}

struct Reminder: Codable, Identifiable, Equatable {
    var id: UUID
    var kind: ReminderKind
    var title: String
    var date: Date
    var enabled: Bool

    init(id: UUID = UUID(), kind: ReminderKind, title: String, date: Date, enabled: Bool = true) {
        self.id = id
        self.kind = kind
        self.title = title
        self.date = date
        self.enabled = enabled
    }
}

// MARK: - History

enum HistoryKind: String, Codable {
    case added, laidOut, cutListed, tied, pourReady, edited, removed, note

    var icon: String {
        switch self {
        case .added:     return "plus.circle.fill"
        case .laidOut:   return "square.grid.3x3.fill"
        case .cutListed: return "scissors"
        case .tied:      return "link"
        case .pourReady: return "checkmark.seal.fill"
        case .edited:    return "pencil.circle.fill"
        case .removed:   return "trash.fill"
        case .note:      return "text.bubble.fill"
        }
    }
    var color: UInt {
        switch self {
        case .added:     return 0x2D70EA
        case .laidOut:   return 0x38BDF8
        case .cutListed: return 0xF2792E
        case .tied:      return 0xF5B400
        case .pourReady: return 0x22C55E
        case .edited:    return 0x6A9DF4
        case .removed:   return 0xEF4444
        case .note:      return 0xA7BAD6
        }
    }
}

struct HistoryEvent: Codable, Identifiable, Equatable {
    var id: UUID
    var kind: HistoryKind
    var message: String
    var date: Date

    init(id: UUID = UUID(), kind: HistoryKind, message: String, date: Date = Date()) {
        self.id = id
        self.kind = kind
        self.message = message
        self.date = date
    }
}

// MARK: - Root persisted state

struct AppData: Codable {
    var elements: [RebarElement]
    var settings: ProjectSettings
    var reminders: [Reminder]
    var history: [HistoryEvent]

    init(elements: [RebarElement] = [],
         settings: ProjectSettings = ProjectSettings(),
         reminders: [Reminder] = [],
         history: [HistoryEvent] = []) {
        self.elements = elements
        self.settings = settings
        self.reminders = reminders
        self.history = history
    }
}
