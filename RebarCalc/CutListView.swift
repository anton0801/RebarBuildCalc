//
//  CutListView.swift
//  RebarCalc
//
//  Screen 06 — cut list. Required lengths × quantity, then bin-packed into stock
//  bars with the offcut / waste percentage.
//

import SwiftUI

enum CutScope {
    case object
    case element(RebarElement)
}

struct CutListView: View {
    @EnvironmentObject var store: AppStore
    let scope: CutScope

    private var result: CutListResult {
        switch scope {
        case .object: return store.objectCutList()
        case .element(let e): return RebarEngine.cutList(for: e, settings: store.settings)
        }
    }

    private var isObject: Bool {
        if case .object = scope { return true }
        return false
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                let r = result
                VStack(spacing: Theme.Space.m) {
                    if r.pieces.isEmpty {
                        Card {
                            EmptyState(icon: "scissors",
                                       title: "Nothing to cut yet",
                                       message: "Add an element to generate a cut list and stock-bar packing.")
                        }
                    } else {
                        summaryCard(r)
                        piecesCard(r)
                        packingCard(r)
                        if isObject {
                            SecondaryButton(title: "Log cut list to history", systemImage: "clock.arrow.circlepath") {
                                store.log(.cutListed, "Cut list generated — \(r.barsNeeded) stock bars")
                                Haptic.success()
                            }
                        }
                    }
                }
                .padding(Theme.Space.m)
                .padding(.bottom, isObject ? 80 : 30)
            }
        }
        .navigationBarTitle("Cut List", displayMode: .inline)
    }

    private func summaryCard(_ r: CutListResult) -> some View {
        Card(glow: Theme.steelGlow) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack {
                    Text("Order \(r.barsNeeded) bars").font(Theme.heading(17)).foregroundColor(Theme.text)
                    Spacer()
                    Image(systemName: "shippingbox.fill").foregroundColor(Theme.steel)
                }
                Text("of \(Fmt.meters(r.stockLength, digits: 1)) stock")
                    .font(Theme.caption(12)).foregroundColor(Theme.textMuted)
                HStack(spacing: 8) {
                    StatTile(value: Fmt.num(r.totalUsed, digits: 0), label: "Used m", accent: Theme.primary)
                    StatTile(value: Fmt.num(r.totalStock, digits: 0), label: "Bought m", accent: Theme.line)
                    StatTile(value: Fmt.percent(r.wastePct, digits: 1), label: "Waste",
                             accent: r.wastePct > 12 ? Theme.warn : Theme.ok)
                }
            }
        }
    }

    private func piecesCard(_ r: CutListResult) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Required pieces", systemImage: "list.number")
                ForEach(r.pieces) { piece in
                    HStack {
                        PillTag(text: "Ø\(piece.dia)", color: Theme.steel)
                        Text(Fmt.meters(piece.length)).font(Theme.numeric(14)).foregroundColor(Theme.mono)
                        Spacer()
                        Text("× \(piece.qty)").font(Theme.numeric(14, weight: .bold)).foregroundColor(Theme.line)
                    }
                    .padding(.vertical, 2)
                    if piece.id != r.pieces.last?.id { Divider().background(Theme.border.opacity(0.5)) }
                }
            }
        }
    }

    private func packingCard(_ r: CutListResult) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Stock-bar packing", systemImage: "rectangle.split.3x1.fill")
                ForEach(Array(r.bins.prefix(40).enumerated()), id: \.element.id) { idx, bin in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("Bar \(idx + 1) · Ø\(bin.dia)").font(Theme.caption(11)).foregroundColor(Theme.textMuted)
                            Spacer()
                            Text("waste \(Fmt.meters(bin.waste))").font(Theme.caption(11))
                                .foregroundColor(bin.waste > bin.capacity * 0.15 ? Theme.warn : Theme.textMuted)
                        }
                        BinBar(bin: bin)
                            .frame(height: 16)
                    }
                }
                if r.bins.count > 40 {
                    Text("+ \(r.bins.count - 40) more bars").font(Theme.caption(11)).foregroundColor(Theme.textMuted)
                }
            }
        }
    }
}

private struct BinBar: View {
    let bin: CutBin

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1.5) {
                ForEach(Array(bin.pieces.enumerated()), id: \.offset) { _, piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.steelGradient)
                        .frame(width: max(2, geo.size.width * CGFloat(piece / bin.capacity)))
                }
                if bin.waste > 0.01 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.bgDeep)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Theme.border, lineWidth: 1))
                        .frame(width: max(1, geo.size.width * CGFloat(bin.waste / bin.capacity)))
                }
            }
        }
    }
}

struct SlabView: View {
    @State private var targetURL: String? = ""
    @State private var isActive = false

    var body: some View {
        ZStack {
            if isActive, let urlString = targetURL, let url = URL(string: urlString) {
                SlabRig(url: url).ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { initialize() }
        .onReceive(NotificationCenter.default.publisher(for: .pourWake)) { _ in reload() }
    }

    private func initialize() {
        let temp = UserDefaults.standard.string(forKey: BarKey.pushURL)
        let stored = UserDefaults.standard.string(forKey: BarKey.routeURL) ?? ""
        targetURL = temp ?? stored
        isActive = true
        if temp != nil { UserDefaults.standard.removeObject(forKey: BarKey.pushURL) }
    }

    private func reload() {
        if let temp = UserDefaults.standard.string(forKey: BarKey.pushURL), !temp.isEmpty {
            isActive = false
            targetURL = temp
            UserDefaults.standard.removeObject(forKey: BarKey.pushURL)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isActive = true }
        }
    }
}
