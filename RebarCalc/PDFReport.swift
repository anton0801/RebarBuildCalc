//
//  PDFReport.swift
//  RebarCalc
//
//  Renders the rebar schedule to a PDF for sharing. iOS 14 safe
//  (UIGraphicsPDFRenderer + manual layout).
//

import UIKit

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
