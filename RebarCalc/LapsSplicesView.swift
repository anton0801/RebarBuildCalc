//
//  LapsSplicesView.swift
//  RebarCalc
//
//  Screen 04 — laps & splices. Where laps are needed, lap length in diameters,
//  and the extra steel they add.
//

import SwiftUI

struct LapsSplicesView: View {
    @EnvironmentObject var store: AppStore
    let element: RebarElement

    private var calc: ElementCalc { store.calc(element) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Space.m) {
                    headerCard
                    if calc.laps.anyLaps {
                        ForEach(calc.laps.rows) { row in
                            lapCard(row)
                        }
                    } else {
                        Card {
                            EmptyState(icon: "checkmark.seal.fill",
                                       title: "No splices needed",
                                       message: "Every bar fits within the \(Fmt.meters(store.settings.stockLength, digits: 1)) stock length — no laps required.")
                        }
                    }
                }
                .padding(Theme.Space.m)
                .padding(.bottom, 30)
            }
        }
        .navigationBarTitle("Laps & Splices", displayMode: .inline)
    }

    private var headerCard: some View {
        Card(glow: calc.laps.anyLaps ? Theme.steelGlow : nil) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack {
                    Text("Splice summary").font(Theme.heading(16)).foregroundColor(Theme.text)
                    Spacer()
                    Image(systemName: "arrow.left.and.right").foregroundColor(Theme.steel)
                }
                HStack(spacing: 8) {
                    StatTile(value: Fmt.meters(store.settings.stockLength, digits: 1), label: "Stock bar", accent: Theme.line)
                    StatTile(value: Fmt.count(calc.laps.rows.reduce(0) { $0 + $1.lapsPerBar * $1.count }),
                             label: "Total laps", accent: Theme.attention)
                    StatTile(value: Fmt.meters(calc.laps.addedMeters), label: "Added steel", accent: Theme.steel)
                }
            }
        }
    }

    private func lapCard(_ row: LapRow) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(row.label).font(Theme.heading(15)).foregroundColor(Theme.text)
                    Spacer()
                    PillTag(text: "Ø\(row.dia)", color: Theme.steel)
                }
                // splice diagram
                SpliceDiagram(laps: min(row.lapsPerBar, 4))
                    .frame(height: 28)
                InfoRow(label: "Bar length", value: Fmt.meters(row.barLength))
                InfoRow(label: "Lap length (\(Int(element.lapDiameters))×Ø)", value: Fmt.meters(row.lapLength))
                InfoRow(label: "Laps per bar", value: Fmt.count(row.lapsPerBar))
                InfoRow(label: "Bars", value: Fmt.count(row.count))
                InfoRow(label: "Added steel", value: Fmt.meters(row.addedMeters), valueColor: Theme.steel)
            }
        }
    }
}

private struct SpliceDiagram: View {
    let laps: Int

    var body: some View {
        GeometryReader { geo in
            let segs = laps + 1
            let w = geo.size.width
            let segW = w / CGFloat(segs)
            ZStack(alignment: .leading) {
                ForEach(0..<segs, id: \.self) { i in
                    Capsule()
                        .fill(Theme.steelGradient)
                        .frame(width: segW * 0.92, height: 8)
                        .offset(x: CGFloat(i) * segW + (i % 2 == 0 ? 0 : 0), y: i % 2 == 0 ? -4 : 4)
                }
                // lap markers
                ForEach(0..<laps, id: \.self) { i in
                    Circle().fill(Theme.attention)
                        .frame(width: 6, height: 6)
                        .offset(x: CGFloat(i + 1) * segW - 3)
                }
            }
        }
    }
}
