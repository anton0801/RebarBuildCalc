//
//  ReportsView.swift
//  RebarCalc
//
//  Screen 15 — reports. The whole-object rebar schedule with PDF export, plus
//  links to material cost and reminders.
//

import SwiftUI

struct ReportsView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage("currencySymbol") private var currency = "$"

    @State private var shareURL: ShareItem?

    var body: some View {
        NavigationView {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Space.m) {
                        summaryCard
                        exportButton
                        linksRow
                        SectionHeader(title: "Schedule", systemImage: "tablecells.fill").padding(.top, 4)
                        if store.elements.isEmpty {
                            Card { EmptyState(icon: "doc.text", title: "No data", message: "Add elements to build the schedule.") }
                        } else {
                            scheduleCard
                            cutCard
                        }
                    }
                    .padding(Theme.Space.m)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitle("Reports", displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(item: $shareURL) { item in
            ShareSheet(items: [item.url])
        }
    }

    private var summaryCard: some View {
        let s = store.summary()
        return Card(glow: Theme.blueGlow) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text("Object totals").font(Theme.heading(16)).foregroundColor(Theme.text)
                HStack(spacing: 8) {
                    StatTile(value: Fmt.num(s.totalMeters, digits: 0), label: "Linear m", accent: Theme.line)
                    StatTile(value: Fmt.num(s.totalTonnes, digits: 3), label: "Tonnes", accent: Theme.steel)
                    StatTile(value: Fmt.count(s.elementCount), label: "Elements", accent: Theme.primary)
                }
            }
        }
    }

    private var exportButton: some View {
        PrimaryButton(title: "Export PDF schedule", systemImage: "square.and.arrow.up") {
            if let url = PDFReport.make(elements: store.elements, settings: store.settings, currency: currency) {
                shareURL = ShareItem(url: url)
                store.log(.note, "Exported PDF schedule")
            }
        }
    }

    private var linksRow: some View {
        HStack(spacing: 10) {
            NavigationLink(destination: MaterialCostView()) {
                reportLink("Material Cost", "dollarsign.circle.fill", Theme.primary)
            }.buttonStyle(PlainButtonStyle())
            NavigationLink(destination: RemindersView()) {
                reportLink("Reminders", "bell.badge.fill", Theme.attention)
            }.buttonStyle(PlainButtonStyle())
        }
    }

    private func reportLink(_ title: String, _ icon: String, _ accent: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold))
            Text(title).font(Theme.heading(14))
        }
        .foregroundColor(Theme.onSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(accent.opacity(0.4), lineWidth: 1)))
    }

    private var scheduleCard: some View {
        Card {
            VStack(spacing: 6) {
                HStack {
                    Text("ELEMENT").font(Theme.caption(10)).foregroundColor(Theme.textMuted).frame(maxWidth: .infinity, alignment: .leading)
                    Text("BARS").font(Theme.caption(10)).foregroundColor(Theme.textMuted).frame(width: 44, alignment: .trailing)
                    Text("M").font(Theme.caption(10)).foregroundColor(Theme.textMuted).frame(width: 56, alignment: .trailing)
                    Text("KG").font(Theme.caption(10)).foregroundColor(Theme.textMuted).frame(width: 60, alignment: .trailing)
                }
                ForEach(store.elements) { e in
                    let c = store.calc(e)
                    Divider().background(Theme.border.opacity(0.5))
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.name).font(Theme.body(13)).foregroundColor(Theme.text).lineLimit(1)
                            Text(e.type.short).font(Theme.caption(10)).foregroundColor(Theme.textMuted)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Text(Fmt.count(c.barCount)).font(Theme.numeric(12)).foregroundColor(Theme.line).frame(width: 44, alignment: .trailing)
                        Text(Fmt.num(c.totalMeters, digits: 1)).font(Theme.numeric(12)).foregroundColor(Theme.mono).frame(width: 56, alignment: .trailing)
                        Text(Fmt.num(c.totalMass, digits: 1)).font(Theme.numeric(12, weight: .bold)).foregroundColor(Theme.steel).frame(width: 60, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var cutCard: some View {
        let cut = store.objectCutList()
        return Card {
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Cut list", systemImage: "scissors")
                InfoRow(label: "Stock bars to order", value: Fmt.count(cut.barsNeeded), valueColor: Theme.steel)
                InfoRow(label: "Waste", value: Fmt.percent(cut.wastePct, digits: 1),
                        valueColor: cut.wastePct > 12 ? Theme.warn : Theme.ok)
            }
        }
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
