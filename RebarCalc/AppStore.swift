//
//  AppStore.swift
//  RebarCalc
//
//  The single source of truth. Owns AppData, performs all CRUD, exposes derived
//  engine results, and persists every mutation.
//

import SwiftUI

final class AppStore: ObservableObject {
    @Published var data: AppData {
        didSet { persistence.save(data) }
    }

    private let persistence = PersistenceManager.shared

    init() {
        if let loaded = persistence.load() {
            self.data = loaded
        } else {
            self.data = SampleData.make()
        }
    }

    // MARK: - Settings

    var settings: ProjectSettings { data.settings }
    func updateSettings(_ s: ProjectSettings) { data.settings = s }

    // MARK: - Elements

    var elements: [RebarElement] { data.elements }

    func element(_ id: UUID) -> RebarElement? { data.elements.first { $0.id == id } }

    func addElement(_ e: RebarElement) {
        data.elements.append(e)
        log(.added, "Added “\(e.name)”")
    }

    /// Builds a blank element seeded from the onboarding preferences.
    func makeBlankElement() -> RebarElement {
        let prefType = ElementType(rawValue: UserDefaults.standard.string(forKey: "prefElement") ?? "") ?? .slab
        var e = RebarElement.blank(type: prefType, settings: settings)
        let dia = UserDefaults.standard.integer(forKey: "prefMainDia")
        if dia > 0 { e.mainDia = dia }
        let sp = UserDefaults.standard.double(forKey: "prefSpacing")
        if sp > 0 { e.mainSpacing = sp }
        return e
    }

    func updateElement(_ e: RebarElement) {
        if let i = data.elements.firstIndex(where: { $0.id == e.id }) {
            data.elements[i] = e
            log(.edited, "Edited “\(e.name)”")
        }
    }

    func deleteElement(_ e: RebarElement) {
        PhotoStore.shared.delete(e.photoFile)
        data.elements.removeAll { $0.id == e.id }
        log(.removed, "Removed “\(e.name)”")
    }

    func deleteElements(at offsets: IndexSet) {
        let removed = offsets.map { data.elements[$0] }
        for e in removed { PhotoStore.shared.delete(e.photoFile) }
        data.elements.remove(atOffsets: offsets)
        for e in removed { log(.removed, "Removed “\(e.name)”") }
    }

    func setPhoto(_ filename: String?, for id: UUID) {
        guard let i = data.elements.firstIndex(where: { $0.id == id }) else { return }
        PhotoStore.shared.delete(data.elements[i].photoFile)
        data.elements[i].photoFile = filename
        log(.note, filename == nil ? "Photo removed from “\(data.elements[i].name)”"
                                   : "Photo attached to “\(data.elements[i].name)”")
    }

    func setChecklist(_ list: PrePourChecklist, for id: UUID) {
        guard let i = data.elements.firstIndex(where: { $0.id == id }) else { return }
        data.elements[i].checklist = list
        let ready = list.allDone
        let wasReady = data.elements[i].pourReady
        data.elements[i].pourReady = ready
        if ready && !wasReady {
            log(.pourReady, "“\(data.elements[i].name)” marked pour-ready")
        }
    }

    func markLaidOut(_ id: UUID) {
        guard let e = element(id) else { return }
        log(.laidOut, "Laid out “\(e.name)”")
    }

    // MARK: - Derived engine results

    func calc(_ e: RebarElement) -> ElementCalc { RebarEngine.calc(for: e, settings: settings) }

    func summary() -> ObjectSummary { RebarEngine.objectSummary(elements: elements, settings: settings) }

    func objectCutList() -> CutListResult { RebarEngine.cutList(forAll: elements, settings: settings) }

    func cost() -> CostBreakdown { CostEngine.breakdown(elements: elements, settings: settings) }

    // MARK: - Reminders

    var reminders: [Reminder] { data.reminders.sorted { $0.date < $1.date } }

    func addReminder(_ r: Reminder) {
        data.reminders.append(r)
        if r.enabled { NotificationManager.shared.schedule(r) }
        log(.note, "Reminder set: \(r.title)")
    }

    func updateReminder(_ r: Reminder) {
        if let i = data.reminders.firstIndex(where: { $0.id == r.id }) {
            data.reminders[i] = r
            NotificationManager.shared.cancel(r)
            if r.enabled && r.date > Date() { NotificationManager.shared.schedule(r) }
        }
    }

    func deleteReminder(_ r: Reminder) {
        NotificationManager.shared.cancel(r)
        data.reminders.removeAll { $0.id == r.id }
    }

    func resyncReminders() {
        NotificationManager.shared.sync(data.reminders)
    }

    // MARK: - History

    var history: [HistoryEvent] { data.history.sorted { $0.date > $1.date } }

    func log(_ kind: HistoryKind, _ message: String) {
        data.history.append(HistoryEvent(kind: kind, message: message))
        if data.history.count > 250 {
            data.history.removeFirst(data.history.count - 250)
        }
    }

    func clearHistory() {
        data.history.removeAll()
    }

    // MARK: - Lifecycle / maintenance

    func flush() { persistence.flush(data) }

    func loadSample() {
        data = SampleData.make()
        resyncReminders()
        log(.note, "Loaded sample object")
    }

    func wipeAll() {
        for e in data.elements { PhotoStore.shared.delete(e.photoFile) }
        NotificationManager.shared.cancelAll()
        data = AppData(elements: [], settings: data.settings, reminders: [], history: [])
        log(.note, "Cleared all data")
    }
}

final class Bay {
    let shelf: Shelf
    let caliper: Caliper
    let mill: Mill
    let cinch: Cinch

    init(shelf: Shelf, caliper: Caliper, mill: Mill, cinch: Cinch) {
        self.shelf = shelf
        self.caliper = caliper
        self.mill = mill
        self.cinch = cinch
    }

    static func stocked() -> Bay {
        Bay(
            shelf: SteelShelf(),
            caliper: BarCaliper(),
            mill: RollMill(),
            cinch: TieCinch()
        )
    }
}

@MainActor
final class Foreman {

    static let shared = Foreman()

    private var crew: [String: Any] = [:]

    private init() {}

    func place<T>(_ instance: T, as type: T.Type) {
        crew[String(describing: type)] = instance
    }

    func assign<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        if let instance = crew[key] as? T {
            return instance
        }
        let raised = draft(type)
        crew[key] = raised
        return raised
    }

    private func draft<T>(_ type: T.Type) -> T {
        switch String(describing: type) {
        case String(describing: Bay.self):
            return Bay.stocked() as! T
        case String(describing: RebarRig.self):
            return RebarRig(bay: assign(Bay.self)) as! T
        default:
            fatalError("Foreman: no builder for \(type)")
        }
    }
}
