//
//  StirrupsTiesView.swift
//  RebarCalc
//
//  Screen 05 — stirrups & ties. Count along the member, the closed-stirrup
//  perimeter with hooks, and total transverse steel.
//

import SwiftUI

struct StirrupsTiesView: View {
    @EnvironmentObject var store: AppStore
    let element: RebarElement

    private var calc: ElementCalc { store.calc(element) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Space.m) {
                    if let s = calc.stirrups {
                        summaryCard(s)
                        perimeterCard(s)
                        Card {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("How it's counted").font(Theme.heading(14)).foregroundColor(Theme.text)
                                Text("Stirrups = floor(clear length ÷ spacing) + 1. One closed stirrup wraps the section inside the cover, plus two hook legs of \(Fmt.mm(s.hookLength * 1000)) each.")
                                    .font(Theme.body(13)).foregroundColor(Theme.textSecond)
                            }
                        }
                    } else {
                        Card {
                            EmptyState(icon: "square.dashed",
                                       title: "No stirrups here",
                                       message: "Slabs use a distribution mesh instead of stirrups. See Bar Layout for the mesh counts.")
                        }
                    }
                }
                .padding(Theme.Space.m)
                .padding(.bottom, 30)
            }
        }
        .navigationBarTitle("Stirrups & Ties", displayMode: .inline)
    }

    private func summaryCard(_ s: StirrupInfo) -> some View {
        Card(glow: Theme.blueGlow) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack {
                    Text("Stirrups").font(Theme.heading(16)).foregroundColor(Theme.text)
                    Spacer()
                    PillTag(text: "Ø\(s.dia) @ \(Int(s.spacing))", color: Theme.attention)
                }
                HStack(spacing: 8) {
                    StatTile(value: Fmt.count(s.count), label: "Count", accent: Theme.line)
                    StatTile(value: Fmt.meters(s.perimeter), label: "Perimeter", accent: Theme.primary)
                    StatTile(value: Fmt.meters(s.totalLength), label: "Total length", accent: Theme.steel)
                }
            }
        }
    }

    private func perimeterCard(_ s: StirrupInfo) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "One stirrup", systemImage: "square.dashed")
                HStack(spacing: Theme.Space.m) {
                    StirrupDrawing()
                        .frame(width: 110, height: 110)
                    VStack(alignment: .leading, spacing: 6) {
                        InfoRow(label: "Inner width", value: Fmt.mm(s.innerB))
                        InfoRow(label: "Inner height", value: Fmt.mm(s.innerH))
                        InfoRow(label: "Hook leg", value: Fmt.mm(s.hookLength * 1000))
                        InfoRow(label: "Cut length", value: Fmt.meters(s.perimeter), valueColor: Theme.steel)
                    }
                }
            }
        }
    }
}

private struct StirrupDrawing: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Theme.bgDeep)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Theme.attention, lineWidth: 2.4)
                    .padding(18)
                // hook
                Path { p in
                    p.move(to: CGPoint(x: geo.size.width - 22, y: 18))
                    p.addLine(to: CGPoint(x: geo.size.width - 34, y: 30))
                }.stroke(Theme.steel, lineWidth: 2.4)
            }
        }
    }
}
