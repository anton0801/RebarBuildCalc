//
//  WeightTonnageView.swift
//  RebarCalc
//
//  Screen 07 — weight & tonnage. Metres → mass by diameter, element total and
//  the running object tonnage for ordering.
//

import SwiftUI

struct WeightTonnageView: View {
    @EnvironmentObject var store: AppStore
    let element: RebarElement

    private var calc: ElementCalc { store.calc(element) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Space.m) {
                    totalsCard
                    breakdownCard
                    objectCard
                }
                .padding(Theme.Space.m)
                .padding(.bottom, 30)
            }
        }
        .navigationBarTitle("Weight & Tonnage", displayMode: .inline)
    }

    private var totalsCard: some View {
        Card(glow: Theme.steelGlow) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack {
                    Text(element.name).font(Theme.heading(16)).foregroundColor(Theme.text).lineLimit(1)
                    Spacer()
                    Image(systemName: "scalemass.fill").foregroundColor(Theme.steel)
                }
                HStack(spacing: 8) {
                    StatTile(value: Fmt.num(calc.totalMeters, digits: 1), label: "Linear m", accent: Theme.primary)
                    StatTile(value: Fmt.num(calc.totalMass, digits: 1), label: "Kg", accent: Theme.steel)
                    StatTile(value: Fmt.num(calc.totalMass / 1000, digits: 3), label: "Tonnes", accent: Theme.line)
                }
            }
        }
    }

    private var breakdownCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "By diameter", systemImage: "circle.circle.fill")
                HStack {
                    Text("Ø").font(Theme.caption(11)).foregroundColor(Theme.textMuted).frame(width: 40, alignment: .leading)
                    Text("LENGTH").font(Theme.caption(11)).foregroundColor(Theme.textMuted).frame(maxWidth: .infinity, alignment: .trailing)
                    Text("KG/M").font(Theme.caption(11)).foregroundColor(Theme.textMuted).frame(maxWidth: .infinity, alignment: .trailing)
                    Text("MASS").font(Theme.caption(11)).foregroundColor(Theme.textMuted).frame(maxWidth: .infinity, alignment: .trailing)
                }
                ForEach(calc.weight.rows) { row in
                    Divider().background(Theme.border.opacity(0.5))
                    HStack {
                        PillTag(text: "Ø\(row.dia)", color: Theme.steel).frame(width: 40, alignment: .leading)
                        Text(Fmt.meters(row.meters)).font(Theme.numeric(13)).foregroundColor(Theme.mono)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text(Fmt.num(row.kgPerM, digits: 3)).font(Theme.numeric(13)).foregroundColor(Theme.textSecond)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text(Fmt.kg(row.mass)).font(Theme.numeric(13, weight: .bold)).foregroundColor(Theme.steel)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var objectCard: some View {
        let s = store.summary()
        return Card {
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Whole object", systemImage: "building.2.fill")
                InfoRow(label: "Total steel", value: Fmt.kg(s.totalMassKg))
                InfoRow(label: "Order tonnage", value: Fmt.tonnes(s.totalTonnes), valueColor: Theme.line)
                Text("Weights use the d²/162 table (editable in Settings).")
                    .font(Theme.caption(11)).foregroundColor(Theme.textMuted).padding(.top, 2)
            }
        }
    }
}
