//
//  MeshSpacersView.swift
//  RebarCalc
//
//  Screen 09 — mesh cards & spacers. Number of mesh sheets and chair spacers
//  from the spacer grid.
//

import SwiftUI

struct MeshSpacersView: View {
    @EnvironmentObject var store: AppStore
    let element: RebarElement

    private var result: (cards: Int, spacers: Int, area: Double) {
        CostEngine.meshAndSpacers(for: element, settings: store.settings)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                let r = result
                VStack(spacing: Theme.Space.m) {
                    Card(glow: Theme.blueGlow) {
                        VStack(alignment: .leading, spacing: Theme.Space.s) {
                            HStack {
                                Text("Mesh & spacers").font(Theme.heading(16)).foregroundColor(Theme.text)
                                Spacer()
                                Image(systemName: "grid").foregroundColor(Theme.primary)
                            }
                            HStack(spacing: 8) {
                                if element.type.isPlanar {
                                    StatTile(value: Fmt.count(r.cards), label: "Mesh cards", accent: Theme.line)
                                    StatTile(value: Fmt.num(r.area, digits: 1), label: "Area m²", accent: Theme.primary)
                                }
                                StatTile(value: Fmt.count(r.spacers), label: "Chairs", accent: Theme.steel)
                            }
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            SectionHeader(title: "Detail", systemImage: "list.bullet")
                            if element.type.isPlanar {
                                InfoRow(label: "Plan area", value: Fmt.num(r.area, digits: 2) + " m²")
                                InfoRow(label: "Mesh card size", value: "≈ 12 m² (2×6 m)")
                                InfoRow(label: "Mesh cards", value: Fmt.count(r.cards), valueColor: Theme.line)
                            }
                            InfoRow(label: "Spacer grid", value: Fmt.meters(store.settings.spacerSpacing, digits: 1))
                            InfoRow(label: "Chair spacers", value: Fmt.count(r.spacers), valueColor: Theme.steel)
                        }
                    }

                    Card {
                        Text(element.type.isPlanar
                             ? "Mesh cards cover the slab area; chair spacers hold the mesh at the right cover on a \(Fmt.meters(store.settings.spacerSpacing, digits: 1)) grid. Adjust the grid in Settings."
                             : "Chair spacers run along the member to keep the cage at the right cover. Adjust the spacing grid in Settings.")
                            .font(Theme.body(13)).foregroundColor(Theme.textSecond)
                    }
                }
                .padding(Theme.Space.m)
                .padding(.bottom, 30)
            }
        }
        .navigationBarTitle("Mesh & Spacers", displayMode: .inline)
    }
}
