//
//  RebarEngine.swift
//  RebarCalc
//
//  The core layout / cut / weight engine. Pure functions, no UI.
//  All lengths in metres unless a name ends in "Mm".
//

import Foundation

// MARK: - Result types

struct BarSet: Identifiable {
    let id = UUID()
    var label: String
    var dia: Int
    var count: Int
    var lengthEach: Double   // m — base cut length incl. end hooks, before splicing
    var direction: String
    var isStirrup: Bool
}

struct LayoutInfo {
    var mainSet: BarSet
    var secondarySet: BarSet?
    var stirrupSet: BarSet?
    var clearLength: Double
    var clearWidth: Double
    var layers: Int
    var hookLength: Double   // m
}

struct LapRow: Identifiable {
    let id = UUID()
    var label: String
    var dia: Int
    var barLength: Double    // m
    var lapLength: Double    // m
    var lapsPerBar: Int
    var count: Int
    var addedMeters: Double
}

struct LapInfo {
    var rows: [LapRow]
    var addedMeters: Double
    var anyLaps: Bool { !rows.isEmpty }
}

struct StirrupInfo {
    var count: Int
    var perimeter: Double    // m, one closed stirrup incl. hooks
    var hookLength: Double    // m, per hook
    var innerB: Double        // mm
    var innerH: Double        // mm
    var totalLength: Double   // m
    var dia: Int
    var spacing: Double       // mm
}

struct WeightRowResult: Identifiable {
    var id: Int { dia }
    var dia: Int
    var meters: Double
    var kgPerM: Double
    var mass: Double          // kg
}

struct WeightInfo {
    var rows: [WeightRowResult]
    var totalMeters: Double
    var totalMass: Double     // kg
}

struct MinReinfInfo {
    var asProvided: Double    // mm²
    var acGross: Double       // mm²
    var ratio: Double         // %
    var minRatio: Double      // %
    var verdict: ReinforcementVerdict
    var perMeterNote: String?
}

enum BendForm: String {
    case straight = "Straight"
    case lShape = "L-shaped"
    case stirrup = "Closed stirrup"

    var icon: String {
        switch self {
        case .straight: return "minus"
        case .lShape: return "l.joystick.tilt.left.fill"
        case .stirrup: return "square.dashed"
        }
    }
}

struct BendShape: Identifiable {
    let id = UUID()
    var label: String
    var form: BendForm
    var dia: Int
    var legsMm: [Double]      // leg lengths in mm
    var angle: Int            // degrees at bends
    var count: Int
    var cutLength: Double     // m, per piece
}

/// Everything computed for one element, in one pass.
struct ElementCalc {
    var element: RebarElement
    var layout: LayoutInfo
    var laps: LapInfo
    var stirrups: StirrupInfo?
    var weight: WeightInfo
    var minReinf: MinReinfInfo
    var bends: [BendShape]

    var totalMeters: Double { weight.totalMeters }
    var totalMass: Double { weight.totalMass }
    var barCount: Int {
        layout.mainSet.count + (layout.secondarySet?.count ?? 0) + (layout.stirrupSet?.count ?? 0)
    }
    var stirrupCount: Int { stirrups?.count ?? 0 }
}

// MARK: - Cut list

struct CutPiece: Identifiable {
    let id = UUID()
    var dia: Int
    var length: Double        // m
    var qty: Int
    var label: String
}

struct CutBin: Identifiable {
    let id = UUID()
    var dia: Int
    var pieces: [Double]
    var capacity: Double
    var used: Double { pieces.reduce(0, +) }
    var waste: Double { capacity - used }
}

struct CutListResult {
    var pieces: [CutPiece]
    var bins: [CutBin]
    var stockLength: Double
    var barsNeeded: Int
    var totalStock: Double
    var totalUsed: Double
    var wasteMeters: Double
    var wastePct: Double
}

// MARK: - Engine

enum RebarEngine {

    private static func clamp(_ v: Double) -> Double { max(0, v) }

    static func hookLength(dia: Int, settings: ProjectSettings) -> Double {
        max(settings.hookFactor * Double(dia), settings.minHook) / 1000.0
    }

    // MARK: Layout

    static func layout(for e: RebarElement, settings: ProjectSettings) -> LayoutInfo {
        let coverM = e.cover / 1000.0
        let clearLength = clamp(e.length - 2 * coverM)
        let clearWidth = clamp(e.width - 2 * coverM)
        let hook = hookLength(dia: e.mainDia, settings: settings)
        let hookAdd = e.endHooks ? 2 * hook : 0

        if e.type.isPlanar {
            let mainSpacing = max(1, e.mainSpacing)
            let transSpacing = max(1, e.transSpacing)
            let layers = max(1, e.layers)

            let mainCount = (Int((clearWidth * 1000) / mainSpacing) + 1) * layers
            let distCount = (Int((clearLength * 1000) / transSpacing) + 1) * layers

            let mainSet = BarSet(label: "Main bars", dia: e.mainDia, count: max(0, mainCount),
                                 lengthEach: clearLength + hookAdd, direction: "along length", isStirrup: false)
            let distSet = BarSet(label: "Distribution", dia: e.transDia, count: max(0, distCount),
                                 lengthEach: clearWidth + hookAdd, direction: "across width", isStirrup: false)
            return LayoutInfo(mainSet: mainSet, secondarySet: distSet, stirrupSet: nil,
                              clearLength: clearLength, clearWidth: clearWidth, layers: layers, hookLength: hook)
        } else {
            let transSpacing = max(1, e.transSpacing)
            let mainSet = BarSet(label: "Longitudinal", dia: e.mainDia, count: max(0, e.mainCount),
                                 lengthEach: clearLength + hookAdd, direction: "along length", isStirrup: false)

            let stirrup = stirrupInfo(for: e, settings: settings)
            let stirrupSet = BarSet(label: "Stirrups / ties", dia: e.transDia, count: stirrup.count,
                                    lengthEach: stirrup.perimeter, direction: "spaced \(Int(transSpacing)) mm", isStirrup: true)
            return LayoutInfo(mainSet: mainSet, secondarySet: nil, stirrupSet: stirrupSet,
                              clearLength: clearLength, clearWidth: clearWidth, layers: 1, hookLength: hook)
        }
    }

    // MARK: Stirrups

    static func stirrupInfo(for e: RebarElement, settings: ProjectSettings) -> StirrupInfo {
        let coverM = e.cover / 1000.0
        let clearLength = clamp(e.length - 2 * coverM)
        let spacing = max(1, e.transSpacing)
        let count = max(0, Int((clearLength * 1000) / spacing) + 1)

        let innerB = clamp(e.sectionB - 2 * e.cover)
        let innerH = clamp(e.sectionH - 2 * e.cover)
        let hook = hookLength(dia: e.transDia, settings: settings) // m
        // closed stirrup: rectangle perimeter + two 135° hook legs
        let perimeterMm = 2 * (innerB + innerH)
        let perimeter = perimeterMm / 1000.0 + 2 * hook

        return StirrupInfo(count: count, perimeter: perimeter, hookLength: hook,
                           innerB: innerB, innerH: innerH,
                           totalLength: Double(count) * perimeter, dia: e.transDia, spacing: spacing)
    }

    // MARK: Laps

    /// Number of joints (laps) needed for a single bar of `length` cut from `stock`,
    /// with a lap overlap of `lap`.
    static func lapCount(length: Double, stock: Double, lap: Double) -> Int {
        guard length > stock, stock > lap else { return length > stock ? Int(ceil(length / stock)) - 1 : 0 }
        let k = ceil((length - lap) / (stock - lap))
        return max(0, Int(k) - 1)
    }

    static func laps(for e: RebarElement, layout: LayoutInfo, settings: ProjectSettings) -> LapInfo {
        var rows: [LapRow] = []
        var added = 0.0
        let stock = max(0.1, settings.stockLength)

        func consider(_ set: BarSet) {
            guard !set.isStirrup, set.count > 0 else { return }
            let lap = e.lapDiameters * Double(set.dia) / 1000.0
            let n = lapCount(length: set.lengthEach, stock: stock, lap: lap)
            guard n > 0 else { return }
            let addEach = Double(n) * lap
            let total = addEach * Double(set.count)
            added += total
            rows.append(LapRow(label: set.label, dia: set.dia, barLength: set.lengthEach,
                               lapLength: lap, lapsPerBar: n, count: set.count, addedMeters: total))
        }
        consider(layout.mainSet)
        if let s = layout.secondarySet { consider(s) }
        return LapInfo(rows: rows, addedMeters: added)
    }

    // MARK: Weight

    static func weight(for e: RebarElement, layout: LayoutInfo, laps: LapInfo, settings: ProjectSettings) -> WeightInfo {
        var metersByDia: [Int: Double] = [:]

        func add(_ set: BarSet?) {
            guard let set = set, set.count > 0 else { return }
            metersByDia[set.dia, default: 0] += set.lengthEach * Double(set.count)
        }
        add(layout.mainSet)
        add(layout.secondarySet)
        add(layout.stirrupSet)

        // Distribute lap additions by diameter.
        for row in laps.rows {
            metersByDia[row.dia, default: 0] += row.addedMeters
        }

        var rows: [WeightRowResult] = []
        var totalM = 0.0
        var totalKg = 0.0
        for dia in metersByDia.keys.sorted() {
            let m = metersByDia[dia] ?? 0
            let kgPerM = settings.kgPerMeter(dia)
            let mass = m * kgPerM
            rows.append(WeightRowResult(dia: dia, meters: m, kgPerM: kgPerM, mass: mass))
            totalM += m
            totalKg += mass
        }
        return WeightInfo(rows: rows, totalMeters: totalM, totalMass: totalKg)
    }

    // MARK: Minimum reinforcement

    static func minReinforcement(for e: RebarElement) -> MinReinfInfo {
        let minRatio = RebarReference.minRatioPercent(e.type)
        var asProvided = 0.0
        var ac = 0.0
        var note: String? = nil

        if e.type.isPlanar {
            // Per 1 m strip, one face considered representative.
            let spacing = max(1, e.mainSpacing)
            let barsPerM = 1000.0 / spacing
            asProvided = barsPerM * BarSize.area(e.mainDia) * Double(max(1, e.layers))
            ac = 1000.0 * e.sectionH    // 1 m wide strip × thickness
            note = "Per 1 m strip × \(Int(e.sectionH)) mm thick"
        } else {
            asProvided = Double(e.mainCount) * BarSize.area(e.mainDia)
            ac = e.sectionB * e.sectionH
        }
        let ratio = ac > 0 ? asProvided / ac * 100.0 : 0
        let verdict = RebarReference.verdict(ratio: ratio, type: e.type)
        return MinReinfInfo(asProvided: asProvided, acGross: ac, ratio: ratio,
                            minRatio: minRatio, verdict: verdict, perMeterNote: note)
    }

    // MARK: Bending schedule

    static func bends(for e: RebarElement, layout: LayoutInfo, settings: ProjectSettings) -> [BendShape] {
        var out: [BendShape] = []
        let hookMm = hookLength(dia: e.mainDia, settings: settings) * 1000

        // Main / longitudinal
        if layout.mainSet.count > 0 {
            if e.endHooks {
                let leg = max(0, layout.mainSet.lengthEach * 1000 - 2 * hookMm)
                out.append(BendShape(label: layout.mainSet.label, form: .lShape, dia: e.mainDia,
                                     legsMm: [hookMm, leg, hookMm], angle: 90,
                                     count: layout.mainSet.count, cutLength: layout.mainSet.lengthEach))
            } else {
                out.append(BendShape(label: layout.mainSet.label, form: .straight, dia: e.mainDia,
                                     legsMm: [layout.mainSet.lengthEach * 1000], angle: 0,
                                     count: layout.mainSet.count, cutLength: layout.mainSet.lengthEach))
            }
        }
        // Distribution (slab)
        if let dist = layout.secondarySet, dist.count > 0 {
            out.append(BendShape(label: dist.label, form: .straight, dia: dist.dia,
                                 legsMm: [dist.lengthEach * 1000], angle: 0,
                                 count: dist.count, cutLength: dist.lengthEach))
        }
        // Stirrups
        if let s = stirrups(for: e, settings: settings), s.count > 0 {
            out.append(BendShape(label: "Stirrup / tie", form: .stirrup, dia: e.transDia,
                                 legsMm: [s.innerB, s.innerH, s.innerB, s.innerH], angle: 90,
                                 count: s.count, cutLength: s.perimeter))
        }
        return out
    }

    static func stirrups(for e: RebarElement, settings: ProjectSettings) -> StirrupInfo? {
        guard e.type.hasStirrups else { return nil }
        return stirrupInfo(for: e, settings: settings)
    }

    // MARK: Full element calc

    static func calc(for e: RebarElement, settings: ProjectSettings) -> ElementCalc {
        let layout = layout(for: e, settings: settings)
        let laps = laps(for: e, layout: layout, settings: settings)
        let stir = stirrups(for: e, settings: settings)
        let weight = weight(for: e, layout: layout, laps: laps, settings: settings)
        let minR = minReinforcement(for: e)
        let bendList = bends(for: e, layout: layout, settings: settings)
        return ElementCalc(element: e, layout: layout, laps: laps, stirrups: stir,
                           weight: weight, minReinf: minR, bends: bendList)
    }

    // MARK: Cut pieces

    /// All cut pieces for one element (post-splicing), grouped later.
    static func cutPieces(for e: RebarElement, settings: ProjectSettings) -> [(dia: Int, length: Double, label: String)] {
        let layout = layout(for: e, settings: settings)
        let stock = max(0.1, settings.stockLength)
        var pieces: [(dia: Int, length: Double, label: String)] = []

        func split(_ set: BarSet) {
            guard set.count > 0, set.lengthEach > 0 else { return }
            if set.isStirrup {
                for _ in 0..<set.count { pieces.append((set.dia, set.lengthEach, set.label)) }
                return
            }
            let lap = e.lapDiameters * Double(set.dia) / 1000.0
            let n = lapCount(length: set.lengthEach, stock: stock, lap: lap)
            if n == 0 {
                for _ in 0..<set.count { pieces.append((set.dia, set.lengthEach, set.label)) }
            } else {
                let fabTotal = set.lengthEach + Double(n) * lap
                let remainder = fabTotal - Double(n) * stock
                for _ in 0..<set.count {
                    for _ in 0..<n { pieces.append((set.dia, stock, set.label)) }
                    if remainder > 0.01 { pieces.append((set.dia, remainder, set.label)) }
                }
            }
        }
        split(layout.mainSet)
        if let s = layout.secondarySet { split(s) }
        if let s = layout.stirrupSet { split(s) }
        return pieces
    }

    /// First-fit-decreasing bin packing of cut pieces into stock bars, per diameter.
    static func packCutList(pieces raw: [(dia: Int, length: Double, label: String)],
                            stock: Double) -> CutListResult {
        let cap = max(0.1, stock)

        // Aggregate identical (dia, rounded length) for the listing.
        var agg: [String: CutPiece] = [:]
        for p in raw {
            let key = "\(p.dia)|\(Int((p.length * 100).rounded()))"
            if var existing = agg[key] {
                existing.qty += 1
                agg[key] = existing
            } else {
                agg[key] = CutPiece(dia: p.dia, length: p.length, qty: 1, label: p.label)
            }
        }
        let pieceList = agg.values.sorted { ($0.dia, $1.length) < ($1.dia, $0.length) }

        // Bin pack per diameter.
        var bins: [CutBin] = []
        let byDia = Dictionary(grouping: raw, by: { $0.dia })
        for dia in byDia.keys.sorted() {
            let lengths = byDia[dia]!.map { $0.length }.sorted(by: >)
            var diaBins: [[Double]] = []
            for len in lengths {
                let clipped = min(len, cap)
                var placed = false
                for i in diaBins.indices {
                    if diaBins[i].reduce(0, +) + clipped <= cap + 1e-6 {
                        diaBins[i].append(clipped)
                        placed = true
                        break
                    }
                }
                if !placed { diaBins.append([clipped]) }
            }
            for b in diaBins { bins.append(CutBin(dia: dia, pieces: b, capacity: cap)) }
        }

        let barsNeeded = bins.count
        let totalStock = Double(barsNeeded) * cap
        let totalUsed = raw.reduce(0.0) { $0 + min($1.length, cap) }
        let waste = max(0, totalStock - totalUsed)
        let wastePct = totalStock > 0 ? waste / totalStock * 100.0 : 0
        return CutListResult(pieces: pieceList, bins: bins, stockLength: cap,
                             barsNeeded: barsNeeded, totalStock: totalStock,
                             totalUsed: totalUsed, wasteMeters: waste, wastePct: wastePct)
    }

    static func cutList(for e: RebarElement, settings: ProjectSettings) -> CutListResult {
        packCutList(pieces: cutPieces(for: e, settings: settings), stock: settings.stockLength)
    }

    static func cutList(forAll elements: [RebarElement], settings: ProjectSettings) -> CutListResult {
        var all: [(dia: Int, length: Double, label: String)] = []
        for e in elements { all.append(contentsOf: cutPieces(for: e, settings: settings)) }
        return packCutList(pieces: all, stock: settings.stockLength)
    }

    // MARK: Object summary

    static func objectSummary(elements: [RebarElement], settings: ProjectSettings) -> ObjectSummary {
        var meters = 0.0, mass = 0.0, stirr = 0
        for e in elements {
            let c = calc(for: e, settings: settings)
            meters += c.totalMeters
            mass += c.totalMass
            stirr += c.stirrupCount
        }
        return ObjectSummary(totalMeters: meters, totalMassKg: mass,
                             totalStirrups: stirr, elementCount: elements.count)
    }
}

struct ObjectSummary {
    var totalMeters: Double
    var totalMassKg: Double
    var totalStirrups: Int
    var elementCount: Int
    var totalTonnes: Double { totalMassKg / 1000.0 }
}

// MARK: - Material cost

struct CostBreakdown {
    var steelMass: Double      // kg
    var steelCost: Double
    var wireMass: Double       // kg
    var wireCost: Double
    var spacerCount: Int
    var spacerCost: Double
    var laborCost: Double
    var total: Double
}

enum CostEngine {
    static func breakdown(elements: [RebarElement], settings: ProjectSettings) -> CostBreakdown {
        let summary = RebarEngine.objectSummary(elements: elements, settings: settings)
        let steelMass = summary.totalMassKg
        let steelCost = steelMass * settings.steelPrice

        let wireMass = summary.totalTonnes * settings.tieWirePerTonne
        let wireCost = wireMass * settings.tieWirePrice

        // Spacers: one chair per spacerSpacing² of plan area across planar elements,
        // plus a line of chairs along linear elements.
        var spacerCount = 0
        let grid = max(0.1, settings.spacerSpacing)
        for e in elements {
            if e.type.isPlanar {
                let nx = max(1, Int(e.length / grid))
                let ny = max(1, Int(e.width / grid))
                spacerCount += nx * ny
            } else {
                spacerCount += max(1, Int(e.length / grid))
            }
        }
        let spacerCost = Double(spacerCount) * settings.spacerPrice
        let laborCost = summary.totalTonnes * settings.laborPerTonne
        let total = steelCost + wireCost + spacerCost + laborCost
        return CostBreakdown(steelMass: steelMass, steelCost: steelCost,
                             wireMass: wireMass, wireCost: wireCost,
                             spacerCount: spacerCount, spacerCost: spacerCost,
                             laborCost: laborCost, total: total)
    }

    /// Mesh cards & spacers for the Mesh & Spacers screen.
    static func meshAndSpacers(for e: RebarElement, settings: ProjectSettings) -> (cards: Int, spacers: Int, area: Double) {
        let grid = max(0.1, settings.spacerSpacing)
        if e.type.isPlanar {
            let area = e.length * e.width
            // standard mesh card ≈ 2 m × 6 m → 12 m²
            let cards = max(1, Int(ceil(area / 12.0)))
            let nx = max(1, Int(e.length / grid))
            let ny = max(1, Int(e.width / grid))
            return (cards, nx * ny, area)
        } else {
            let spacers = max(1, Int(e.length / grid))
            return (0, spacers, 0)
        }
    }
}
