//
//  RebarBoardView.swift
//  RebarCalc
//
//  Screen 01 — the main board. Object summary + element list with per-element
//  bar count, metres and mass.
//

import SwiftUI

struct RebarBoardView: View {
    @EnvironmentObject var store: AppStore
    @State private var showAdd = false

    var body: some View {
        NavigationView {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Space.m) {
                        summaryCard
                        actionButtons
                        SectionHeader(title: "Elements", systemImage: "square.stack.3d.up.fill")
                            .padding(.top, 4)

                        if store.elements.isEmpty {
                            Card {
                                EmptyState(icon: "square.grid.3x3",
                                           title: "No elements yet",
                                           message: "Add a footing, slab, column or beam to start counting steel.")
                            }
                        } else {
                            ForEach(store.elements) { element in
                                NavigationLink(destination: ElementDetailView(elementID: element.id)) {
                                    ElementRow(calc: store.calc(element))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(Theme.Space.m)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitle("Rebar Board", displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showAdd) {
            AddElementView(initial: store.makeBlankElement()) { newElement in
                store.addElement(newElement)
            }
            .environmentObject(store)
        }
    }

    private var summaryCard: some View {
        let s = store.summary()
        return Card(glow: Theme.blueGlow) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack {
                    Text("Object summary").font(Theme.heading(16)).foregroundColor(Theme.text)
                    Spacer()
                    Image(systemName: "building.2.fill").foregroundColor(Theme.primary)
                }
                HStack(spacing: 8) {
                    StatTile(value: Fmt.num(s.totalMeters, digits: 0), label: "Linear m",
                             accent: Theme.line, systemImage: "ruler")
                    StatTile(value: Fmt.num(s.totalTonnes, digits: 3), label: "Tonnes",
                             accent: Theme.steel, systemImage: "scalemass.fill")
                    StatTile(value: Fmt.count(s.totalStirrups), label: "Stirrups",
                             accent: Theme.attention, systemImage: "square.dashed")
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: "Add Element", systemImage: "plus") { showAdd = true }
            HStack(spacing: 10) {
                NavigationLink(destination: layoutDestination) {
                    boardLinkLabel("Bar Layout", "square.grid.3x3.fill", Theme.line)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(store.elements.isEmpty)
                .opacity(store.elements.isEmpty ? 0.4 : 1)

                NavigationLink(destination: CutListView(scope: .object)) {
                    boardLinkLabel("Cut List", "scissors", Theme.steel)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var layoutDestination: some View {
        if let first = store.elements.first {
            BarLayoutView(element: first)
        } else {
            EmptyView()
        }
    }

    private func boardLinkLabel(_ title: String, _ icon: String, _ accent: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold))
            Text(title).font(Theme.heading(15))
        }
        .foregroundColor(Theme.onSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.m)
                .fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(accent.opacity(0.4), lineWidth: 1))
        )
    }
}

// MARK: - Element row

struct ElementRow: View {
    let calc: ElementCalc

    var body: some View {
        let e = calc.element
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: e.type.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.primary)
                        .frame(width: 40, height: 40)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.primary.opacity(0.15)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.name).font(Theme.heading(16)).foregroundColor(Theme.text).lineLimit(1)
                        Text(e.type.rawValue).font(Theme.caption(12)).foregroundColor(Theme.textMuted)
                    }
                    Spacer()
                    if e.pourReady {
                        StatusBadge(text: "Pour-ready", color: Theme.ok, icon: "checkmark.seal.fill")
                    } else {
                        StatusBadge(text: calc.minReinf.verdict == .low ? "Check steel" : "In work",
                                    color: calc.minReinf.verdict == .low ? Theme.warn : Theme.working,
                                    icon: calc.minReinf.verdict == .low ? "exclamationmark.triangle.fill" : "wrench.and.screwdriver.fill")
                    }
                }
                Divider().background(Theme.border)
                HStack(spacing: 8) {
                    metric(Fmt.count(calc.barCount), "bars", Theme.line)
                    metric(Fmt.num(calc.totalMeters, digits: 1) + " m", "length", Theme.primary)
                    metric(Fmt.kg(calc.totalMass), "mass", Theme.steel)
                }
            }
        }
    }

    private func metric(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Theme.numeric(15, weight: .bold)).foregroundColor(color)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label.uppercased()).font(Theme.caption(9)).tracking(0.5).foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
