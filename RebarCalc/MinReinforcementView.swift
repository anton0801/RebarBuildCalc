//
//  MinReinforcementView.swift
//  RebarCalc
//
//  Screen 08 — minimum reinforcement check. Steel area / concrete area vs the
//  minimum ratio, with a low / ok verdict.
//

import SwiftUI

struct MinReinforcementView: View {
    @EnvironmentObject var store: AppStore
    let element: RebarElement

    private var info: MinReinfInfo { store.calc(element).minReinf }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                let i = info
                let color = Color(hex: i.verdict.colorHex)
                VStack(spacing: Theme.Space.m) {
                    verdictCard(i, color)
                    gaugeCard(i, color)
                    detailCard(i)
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("What this means").font(Theme.heading(14)).foregroundColor(Theme.text)
                            Text(i.verdict == .low
                                 ? "The steel area is below the indicative minimum for a \(element.type.short.lowercased()). Add bars, increase diameter or reduce spacing — and confirm against the engineer's design."
                                 : "The steel ratio sits within the usual range for this element. Always confirm against the project drawings.")
                                .font(Theme.body(13)).foregroundColor(Theme.textSecond)
                        }
                    }
                }
                .padding(Theme.Space.m)
                .padding(.bottom, 30)
            }
        }
        .navigationBarTitle("Min Reinforcement", displayMode: .inline)
    }

    private func verdictCard(_ i: MinReinfInfo, _ color: Color) -> some View {
        Card(glow: color.opacity(0.35)) {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: i.verdict.icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(color.opacity(0.15)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(i.verdict.rawValue).font(Theme.heading(17)).foregroundColor(Theme.text)
                    Text("\(Fmt.percent(i.ratio)) provided · min \(Fmt.percent(i.minRatio))")
                        .font(Theme.caption(12)).foregroundColor(Theme.textSecond)
                }
                Spacer()
            }
        }
    }

    private func gaugeCard(_ i: MinReinfInfo, _ color: Color) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Reinforcement ratio", systemImage: "chart.bar.fill")
                RatioGauge(ratio: i.ratio, minRatio: i.minRatio, color: color)
                HStack {
                    Text("0%").font(Theme.caption(10)).foregroundColor(Theme.textMuted)
                    Spacer()
                    HStack(spacing: 4) {
                        Rectangle().fill(Theme.attention).frame(width: 2, height: 10)
                        Text("min \(Fmt.percent(i.minRatio))").font(Theme.caption(10)).foregroundColor(Theme.textMuted)
                    }
                }
            }
        }
    }

    private func detailCard(_ i: MinReinfInfo) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Areas", systemImage: "ruler.fill")
                InfoRow(label: "Steel area As", value: Fmt.num(i.asProvided, digits: 0) + " mm²", valueColor: Theme.steel)
                InfoRow(label: "Concrete area Ac", value: Fmt.num(i.acGross, digits: 0) + " mm²")
                InfoRow(label: "Ratio As/Ac", value: Fmt.percent(i.ratio), valueColor: Theme.line)
                if let note = i.perMeterNote {
                    Text(note).font(Theme.caption(11)).foregroundColor(Theme.textMuted).padding(.top, 2)
                }
            }
        }
    }
}
