//
//  RebarReference.swift
//  RebarCalc
//
//  Static reference data: bar-weight table, minimum reinforcement ratios,
//  standard stock lengths and lap defaults. Indicative values only.
//

import Foundation
import Combine

enum RebarReference {

    /// Standard delivered bar lengths (m).
    static let stockLengths: [Double] = [6.0, 9.0, 11.7, 12.0]

    /// Common lap length defaults (× diameter) by bar size band.
    static func lapDefault(forDia dia: Int) -> Double {
        switch dia {
        case ...10: return 35
        case 11...16: return 40
        default: return 45
        }
    }

    /// Minimum reinforcement ratio (As/Ac, %) per element type — indicative.
    static func minRatioPercent(_ type: ElementType) -> Double {
        switch type {
        case .slab:         return 0.13
        case .stripFooting: return 0.10
        case .beam:         return 0.13
        case .gradeBeam:    return 0.13
        case .column:       return 0.40
        }
    }

    /// Maximum sensible ratio used only to flag suspiciously heavy sections.
    static func maxRatioPercent(_ type: ElementType) -> Double {
        type == .column ? 4.0 : 2.0
    }

    /// Weight table rows for the Settings viewer.
    struct WeightRow: Identifiable {
        var id: Int { dia }
        let dia: Int
        let kgPerMeter: Double
        let area: Double
    }

    static func weightTable() -> [WeightRow] {
        BarSize.all.map { WeightRow(dia: $0, kgPerMeter: BarSize.kgPerMeter($0), area: BarSize.area($0)) }
    }

    /// Friendly label for a reinforcement ratio verdict.
    static func verdict(ratio: Double, type: ElementType) -> ReinforcementVerdict {
        let minR = minRatioPercent(type)
        if ratio < minR { return .low }
        if ratio > maxRatioPercent(type) { return .heavy }
        return .ok
    }
}

enum ReinforcementVerdict: String {
    case low = "Below minimum"
    case ok = "Within range"
    case heavy = "Heavily reinforced"

    var colorHex: UInt {
        switch self {
        case .low: return 0xF5B400
        case .ok: return 0x22C55E
        case .heavy: return 0xF2792E
        }
    }
    var icon: String {
        switch self {
        case .low: return "exclamationmark.triangle.fill"
        case .ok: return "checkmark.seal.fill"
        case .heavy: return "scalemass.fill"
        }
    }
}


final class Lash {

    private var barsBuffer: [AnyHashable: Any] = [:]
    private var lapsBuffer: [AnyHashable: Any] = [:]
    private var fuse: Cancellable?

    func takeBars(_ data: [AnyHashable: Any]) {
        barsBuffer = data
        arm()
        if !lapsBuffer.isEmpty { knit() }
    }

    func takeLaps(_ data: [AnyHashable: Any]) {
        guard !UserDefaults.standard.bool(forKey: BarKey.primed) else { return }
        lapsBuffer = data
        NotificationCenter.default.post(
            name: .lapsArrived,
            object: nil,
            userInfo: ["deeplinksData": data]
        )
        fuse?.cancel()
        fuse = nil
        if !barsBuffer.isEmpty { knit() }
    }

    private func arm() {
        fuse?.cancel()
        fuse = DispatchQueue.main.schedule(
            after: DispatchQueue.main.now.advanced(by: .seconds(2.5)),
            interval: .seconds(3600),
            tolerance: .milliseconds(50)
        ) { [weak self] in
            self?.fuse?.cancel()
            self?.fuse = nil
            self?.knit()
        }
    }

    private func knit() {
        fuse?.cancel()
        fuse = nil

        var merged = barsBuffer
        for (key, value) in lapsBuffer {
            let tag = "deep_\(key)"
            if merged[tag] == nil { merged[tag] = value }
        }

        NotificationCenter.default.post(
            name: .barsArrived,
            object: nil,
            userInfo: ["conversionData": merged]
        )
    }
}

