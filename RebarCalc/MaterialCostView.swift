//
//  MaterialCostView.swift
//  RebarCalc
//
//  Screen 11 — material cost. Steel by mass + tie wire + spacers + tying labor
//  for the whole object.
//

import SwiftUI

struct MaterialCostView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage("currencySymbol") private var currency = "$"

    private var cost: CostBreakdown { store.cost() }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                let c = cost
                VStack(spacing: Theme.Space.m) {
                    Card(glow: Theme.blueGlow) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Object total").font(Theme.caption(12)).tracking(0.6).foregroundColor(Theme.textMuted)
                            Text(Fmt.money(c.total, symbol: currency))
                                .font(Theme.numeric(34, weight: .heavy)).foregroundColor(Theme.primary)
                                .lineLimit(1).minimumScaleFactor(0.5)
                        }
                    }

                    Card {
                        VStack(spacing: 4) {
                            costRow("Steel", "\(Fmt.kg(c.steelMass)) @ \(Fmt.money(store.settings.steelPrice, symbol: currency))/kg", c.steelCost, Theme.steel)
                            Divider().background(Theme.border)
                            costRow("Tie wire", "\(Fmt.kg(c.wireMass))", c.wireCost, Theme.line)
                            Divider().background(Theme.border)
                            costRow("Spacers", "\(Fmt.count(c.spacerCount)) chairs", c.spacerCost, Theme.attention)
                            Divider().background(Theme.border)
                            costRow("Tying labor", Fmt.tonnes(c.steelMass / 1000), c.laborCost, Theme.primaryHi)
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Rates", systemImage: "slider.horizontal.3")
                            Text("Edit steel price, wire, spacer price and labor rate in Settings → costs. Currency: \(currency)")
                                .font(Theme.body(13)).foregroundColor(Theme.textSecond)
                        }
                    }
                }
                .padding(Theme.Space.m)
                .padding(.bottom, 30)
            }
        }
        .navigationBarTitle("Material Cost", displayMode: .inline)
    }

    private func costRow(_ title: String, _ detail: String, _ value: Double, _ color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Theme.body(14)).foregroundColor(Theme.text)
                Text(detail).font(Theme.caption(11)).foregroundColor(Theme.textMuted)
            }
            Spacer()
            Text(Fmt.money(value, symbol: currency)).font(Theme.numeric(15, weight: .bold)).foregroundColor(Theme.mono)
        }
        .padding(.vertical, 4)
    }
}
