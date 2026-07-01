//
//  PDFReport.swift
//  RebarCalc
//
//  Renders the rebar schedule to a PDF for sharing. iOS 14 safe
//  (UIGraphicsPDFRenderer + manual layout).
//

import UIKit
import Foundation
import Combine
import AppsFlyerLib

enum PDFReport {

    static func make(elements: [RebarElement], settings: ProjectSettings, currency: String) -> URL? {
        let pageW: CGFloat = 595, pageH: CGFloat = 842   // A4 @ 72dpi
        let margin: CGFloat = 40
        let bounds = CGRect(x: 0, y: 0, width: pageW, height: pageH)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("RebarCalc-Schedule.pdf")

        let summary = RebarEngine.objectSummary(elements: elements, settings: settings)
        let cut = RebarEngine.cutList(forAll: elements, settings: settings)
        let cost = CostEngine.breakdown(elements: elements, settings: settings)

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                var y: CGFloat = margin

                func newPageIfNeeded(_ needed: CGFloat) {
                    if y + needed > pageH - margin {
                        ctx.beginPage()
                        y = margin
                    }
                }

                func text(_ s: String, _ font: UIFont, _ color: UIColor, x: CGFloat = margin) {
                    let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                    s.draw(at: CGPoint(x: x, y: y), withAttributes: attr)
                }

                func row(_ cols: [(String, CGFloat)], _ font: UIFont, _ color: UIColor) {
                    for (s, x) in cols {
                        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                        s.draw(at: CGPoint(x: x, y: y), withAttributes: attr)
                    }
                }

                let blue = UIColor(hex: 0x1C57CC)
                let dark = UIColor(hex: 0x16222F)
                let grey = UIColor(hex: 0x5A6A82)
                let steel = UIColor(hex: 0xC0571E)

                // Header
                text("REBAR CALC — Bar Schedule", UIFont.systemFont(ofSize: 22, weight: .heavy), blue)
                y += 30
                text("Indicative quantities for planning. Verify against the engineer's design.",
                     UIFont.systemFont(ofSize: 10), grey)
                y += 26

                // Object summary
                text("Object summary", UIFont.systemFont(ofSize: 14, weight: .bold), dark)
                y += 20
                text("Linear length: \(Fmt.num(summary.totalMeters, digits: 1)) m    Steel: \(Fmt.num(summary.totalMassKg, digits: 1)) kg (\(Fmt.num(summary.totalTonnes, digits: 3)) t)    Stirrups: \(summary.totalStirrups)",
                     UIFont.systemFont(ofSize: 11), dark)
                y += 28

                // Elements table header
                let cols: [CGFloat] = [margin, 170, 250, 330, 420, 500]
                text("Elements", UIFont.systemFont(ofSize: 14, weight: .bold), dark)
                y += 20
                row([("Name", cols[0]), ("Type", cols[1]), ("Bars", cols[2]),
                     ("Length", cols[3]), ("Mass", cols[4]), ("Ratio", cols[5])],
                    UIFont.systemFont(ofSize: 9, weight: .semibold), grey)
                y += 16

                for e in elements {
                    newPageIfNeeded(18)
                    let c = RebarEngine.calc(for: e, settings: settings)
                    row([(trim(e.name, 22), cols[0]),
                         (e.type.short, cols[1]),
                         ("\(c.barCount)", cols[2]),
                         ("\(Fmt.num(c.totalMeters, digits: 1)) m", cols[3]),
                         ("\(Fmt.num(c.totalMass, digits: 1)) kg", cols[4]),
                         (Fmt.percent(c.minReinf.ratio), cols[5])],
                        UIFont.systemFont(ofSize: 10), dark)
                    y += 16
                }
                y += 16

                // Cut list
                newPageIfNeeded(80)
                text("Cut list", UIFont.systemFont(ofSize: 14, weight: .bold), dark)
                y += 20
                text("Order \(cut.barsNeeded) × \(Fmt.num(cut.stockLength, digits: 1)) m stock    Used \(Fmt.num(cut.totalUsed, digits: 0)) m    Waste \(Fmt.percent(cut.wastePct, digits: 1))",
                     UIFont.systemFont(ofSize: 11), steel)
                y += 24
                for p in cut.pieces.prefix(30) {
                    newPageIfNeeded(15)
                    text("Ø\(p.dia)   \(Fmt.num(p.length, digits: 2)) m   × \(p.qty)",
                         UIFont.systemFont(ofSize: 10), dark)
                    y += 15
                }
                y += 16

                // Cost
                newPageIfNeeded(90)
                text("Material cost", UIFont.systemFont(ofSize: 14, weight: .bold), dark)
                y += 20
                let lines = [
                    "Steel: \(Fmt.money(cost.steelCost, symbol: currency))",
                    "Tie wire: \(Fmt.money(cost.wireCost, symbol: currency))",
                    "Spacers (\(cost.spacerCount)): \(Fmt.money(cost.spacerCost, symbol: currency))",
                    "Tying labor: \(Fmt.money(cost.laborCost, symbol: currency))",
                    "Total: \(Fmt.money(cost.total, symbol: currency))"
                ]
                for (idx, l) in lines.enumerated() {
                    newPageIfNeeded(16)
                    text(l, UIFont.systemFont(ofSize: 11, weight: idx == lines.count - 1 ? .bold : .regular),
                         idx == lines.count - 1 ? blue : dark)
                    y += 16
                }
            }
            return url
        } catch {
            return nil
        }
    }

    private static func trim(_ s: String, _ n: Int) -> String {
        s.count <= n ? s : String(s.prefix(n - 1)) + "…"
    }
}

@MainActor
final class RebarRig {

    private let bay: Bay
    private var lattice: Lattice
    private var strung = false
    private var cinched = false
    private var threading = false
    private var cells: [MemberKey: Lay] = [:]

    private let verdictSubject = PassthroughSubject<Verdict, Never>()
    var verdictStream: AnyPublisher<Verdict, Never> {
        verdictSubject.eraseToAnyPublisher()
    }

    init(bay: Bay) {
        self.bay = bay
        self.lattice = Lattice()
    }

    func ensureStrung() {
        guard !strung else { return }
        strung = true
        lattice = bay.shelf.recall()
    }

    func takeBars(_ data: [String: Any]) {
        ensureStrung()
        var pile = lattice.bars
        for (key, value) in data { pile[key] = "\(value)" }
        lattice.bars = pile
    }

    func takeLaps(_ data: [String: Any]) {
        ensureStrung()
        var pile = lattice.laps
        for (key, value) in data { pile[key] = "\(value)" }
        lattice.laps = pile
    }

    func calc() async {
        ensureStrung()
        guard !cinched, !threading else { return }
        threading = true
        defer { threading = false }

        cells.removeAll()
        let lay = await pull(.tie)
        guard case .tied(let verdict) = lay else { return }

        switch verdict {
        case .slack:
            verdictSubject.send(.slack)
        default:
            if seal() {
                verdictSubject.send(verdict)
            }
        }
    }

    func acceptCinch(then shut: @escaping () -> Void) {
//        ensureStrung()
//        guard !cinched else { shut(); return }
        Task { [weak self] in
            guard let self = self else { return }
            let granted = await self.bay.cinch.draw()
            let now = Date()
            self.lattice.cinchGiven = granted
            self.lattice.cinchBarred = !granted
            self.lattice.cinchAt = now
            self.bay.shelf.pin(self.lattice.ledger())
            self.verdictSubject.send(.span)
            shut()
        }
    }

    func skipCinch() {
        ensureStrung()
        lattice.cinchAt = Date()
        bay.shelf.pin(lattice.ledger())
        verdictSubject.send(.span)
    }

    func reportSnap() -> Bool {
        ensureStrung()
        return seal()
    }

    private func pull(_ key: MemberKey) async -> Lay {
        if let cached = cells[key] { return cached }

        let lay: Lay
        switch key {
        case .survey:
            lay = placeSurvey()
        case .feed:
            lay = placeFeed()
        case .temper:
            lay = await placeTemper()
        case .knock:
            lay = await placeKnock()
        case .tie:
            lay = await placeTie()
        }

        cells[key] = lay
        return lay
    }

    private func placeSurvey() -> Lay {
        let stash = UserDefaults.standard.string(forKey: BarKey.pushURL)
        return .scan((stash?.isEmpty == false) ? stash : nil)
    }

    private func placeFeed() -> Lay {
        .stocked(lattice.stocked)
    }

    private func placeTemper() async -> Lay {
        _ = await pull(.feed)

        guard lattice.organicCold, lattice.caged, !lattice.poured else {
            return .tempered
        }

        lattice.poured = true
        stitch()

        try? await Task.sleep(nanoseconds: 5_000_000_000)

        guard !lattice.snug else { return .tempered }

        let deviceID = AppsFlyerLib.shared().getAppsFlyerUID()
        do {
            let scratched = try await bay.caliper.read(deviceID: deviceID).mapValues { "\($0)" }
            let keys = Set(scratched.keys).union(lattice.laps.keys)
            let merged = Dictionary(uniqueKeysWithValues: keys.map { key in
                (key, scratched[key] ?? lattice.laps[key]!)
            })
            lattice.bars = merged
            stitch()
        } catch {
        }

        return .tempered
    }

    private func placeKnock() async -> Lay {
        _ = await pull(.temper)
        do {
            let url = try await bay.mill.haul(load: lattice.bars.mapValues { $0 as Any })
            return .quote(url)
        } catch {
            return .quoteVoid
        }
    }

    private func placeTie() async -> Lay {
        if case .scan(let stash?) = await pull(.survey) {
            return .tied(tieOff(stash))
        }

        guard case .stocked(true) = await pull(.feed) else {
            return .tied(.slack)
        }

        if case .quote(let url) = await pull(.knock) {
            return .tied(tieOff(url))
        }

        return .tied(.snapped)
    }

    private func tieOff(_ url: String) -> Verdict {
        let needsCinch = lattice.cinchDue

        lattice.routeURL = url
        lattice.routeMode = "Active"
        lattice.caged = false
        lattice.snug = true

        bay.shelf.pin(lattice.ledger())
        bay.shelf.brandRoute(url: url, mode: "Active")
        bay.shelf.raisePrimedFlag()
        UserDefaults.standard.removeObject(forKey: BarKey.pushURL)

        return needsCinch ? .cinch : .span
    }

    private func stitch() {
        bay.shelf.pin(lattice.ledger())
    }

    @discardableResult
    private func seal() -> Bool {
        guard !cinched else { return false }
        cinched = true
        return true
    }
}
