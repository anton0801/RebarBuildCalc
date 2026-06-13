//
//  BarLayoutView.swift
//  RebarCalc
//
//  Screen 03 — bar layout. Longitudinal & transverse counts by spacing with
//  cover, plus a drawn plan/elevation and section schematic.
//

import SwiftUI

struct BarLayoutView: View {
    @EnvironmentObject var store: AppStore
    let element: RebarElement

    private var calc: ElementCalc { store.calc(element) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Space.m) {
                    schematicCard
                    countsCard
                    sectionCard
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("How it's counted").font(Theme.heading(14)).foregroundColor(Theme.text)
                            Text(explanation)
                                .font(Theme.body(13)).foregroundColor(Theme.textSecond)
                        }
                    }
                }
                .padding(Theme.Space.m)
                .padding(.bottom, 30)
            }
        }
        .navigationBarTitle("Bar Layout", displayMode: .inline)
        .onAppear { store.markLaidOut(element.id) }
    }

    // MARK: Plan / elevation schematic

    private var schematicCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: element.type.isPlanar ? "Plan — mesh" : "Elevation — cage",
                              systemImage: "square.grid.3x3.fill")
                if element.type.isPlanar {
                    PlanMesh(mainLines: min(calc.layout.mainSet.count / max(1, calc.layout.layers), 22),
                             distLines: min((calc.layout.secondarySet?.count ?? 0) / max(1, calc.layout.layers), 22))
                        .frame(height: 170)
                } else {
                    ElevationCage(longTop: min(max(1, element.mainCount / 2), 6),
                                  stirrups: min(calc.stirrups?.count ?? 0, 26))
                        .frame(height: 150)
                }
            }
        }
    }

    private var countsCard: some View {
        Card {
            VStack(spacing: 8) {
                barRow(calc.layout.mainSet)
                if let s = calc.layout.secondarySet {
                    Divider().background(Theme.border)
                    barRow(s)
                }
                if let s = calc.layout.stirrupSet {
                    Divider().background(Theme.border)
                    barRow(s)
                }
                Divider().background(Theme.border)
                InfoRow(label: "Clear length", value: Fmt.meters(calc.layout.clearLength))
                if element.type.isPlanar {
                    InfoRow(label: "Clear width", value: Fmt.meters(calc.layout.clearWidth))
                }
            }
        }
    }

    private func barRow(_ set: BarSet) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(set.label).font(Theme.heading(14)).foregroundColor(Theme.text)
                Spacer()
                PillTag(text: "Ø\(set.dia)", color: set.isStirrup ? Theme.attention : Theme.steel)
            }
            HStack(spacing: 8) {
                metric(Fmt.count(set.count), "count", Theme.line)
                metric(Fmt.meters(set.lengthEach), "each", Theme.primary)
                metric(Fmt.meters(set.lengthEach * Double(set.count)), "total", Theme.steel)
            }
            Text(set.direction).font(Theme.caption(11)).foregroundColor(Theme.textMuted)
        }
    }

    private func metric(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(Theme.numeric(14, weight: .bold)).foregroundColor(color)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label.uppercased()).font(Theme.caption(9)).foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sectionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Section", systemImage: "rectangle.dashed")
                HStack(spacing: Theme.Space.m) {
                    SectionDrawing(isPlanar: element.type.isPlanar)
                        .frame(width: 120, height: 120)
                    VStack(alignment: .leading, spacing: 6) {
                        InfoRow(label: element.type.isPlanar ? "Thickness" : "Height h",
                                value: Fmt.mm(element.sectionH))
                        if !element.type.isPlanar {
                            InfoRow(label: "Width b", value: Fmt.mm(element.sectionB))
                        }
                        InfoRow(label: "Cover", value: Fmt.mm(element.cover))
                    }
                }
            }
        }
    }

    private var explanation: String {
        if element.type.isPlanar {
            return "Bars per direction = floor(clear span ÷ spacing) + 1, with the clear span reduced by cover on both edges. \(calc.layout.layers == 2 ? "Counts are doubled for top + bottom mesh." : "Single mesh layer.")"
        } else {
            return "\(element.mainCount) longitudinal bars run the member length. Stirrups = floor(clear length ÷ spacing) + 1, spaced every \(Int(element.transSpacing)) mm."
        }
    }
}

// MARK: - Drawings

private struct PlanMesh: View {
    let mainLines: Int
    let distLines: Int

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Theme.bgDeep)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                let inset: CGFloat = 14
                // main bars (along length) drawn as horizontal blue lines
                Path { p in
                    let n = max(1, mainLines)
                    let h = geo.size.height - inset * 2
                    for i in 0...n {
                        let y = inset + h * CGFloat(i) / CGFloat(n)
                        p.move(to: CGPoint(x: inset, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width - inset, y: y))
                    }
                }.stroke(Theme.line.opacity(0.7), lineWidth: 1.4)
                // distribution bars (across width) as vertical lines
                Path { p in
                    let n = max(1, distLines)
                    let w = geo.size.width - inset * 2
                    for i in 0...n {
                        let x = inset + w * CGFloat(i) / CGFloat(n)
                        p.move(to: CGPoint(x: x, y: inset))
                        p.addLine(to: CGPoint(x: x, y: geo.size.height - inset))
                    }
                }.stroke(Theme.steel.opacity(0.6), lineWidth: 1.2)
            }
        }
    }
}

private struct ElevationCage: View {
    let longTop: Int
    let stirrups: Int

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Theme.bgDeep)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                let inset: CGFloat = 16
                // longitudinal bars (top & bottom) as orange horizontal lines
                Path { p in
                    p.move(to: CGPoint(x: inset, y: inset))
                    p.addLine(to: CGPoint(x: geo.size.width - inset, y: inset))
                    p.move(to: CGPoint(x: inset, y: geo.size.height - inset))
                    p.addLine(to: CGPoint(x: geo.size.width - inset, y: geo.size.height - inset))
                }.stroke(Theme.steel, lineWidth: 2.4)
                // stirrups as vertical blue ticks
                Path { p in
                    let n = max(1, stirrups)
                    let w = geo.size.width - inset * 2
                    for i in 0...n {
                        let x = inset + w * CGFloat(i) / CGFloat(n)
                        p.move(to: CGPoint(x: x, y: inset))
                        p.addLine(to: CGPoint(x: x, y: geo.size.height - inset))
                    }
                }.stroke(Theme.line.opacity(0.6), lineWidth: 1.2)
            }
        }
    }
}

private struct SectionDrawing: View {
    let isPlanar: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Theme.bgDeep)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
                let pad: CGFloat = 16
                // stirrup / cover rectangle
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Theme.line.opacity(0.7), lineWidth: 1.6)
                    .padding(pad)
                // corner / face bars
                if isPlanar {
                    // two layers of dots top & bottom
                    barDots(geo: geo, rows: [pad + 6, geo.size.height - pad - 6], cols: 4)
                } else {
                    barDots(geo: geo, rows: [pad + 6, geo.size.height - pad - 6], cols: 2)
                }
            }
        }
    }

    private func barDots(geo: GeometryProxy, rows: [CGFloat], cols: Int) -> some View {
        ZStack {
            ForEach(0..<rows.count, id: \.self) { r in
                ForEach(0..<cols, id: \.self) { c in
                    Circle().fill(Theme.steel)
                        .frame(width: 7, height: 7)
                        .position(x: 22 + (geo.size.width - 44) * CGFloat(c) / CGFloat(max(1, cols - 1)),
                                  y: rows[r])
                }
            }
        }
    }
}
