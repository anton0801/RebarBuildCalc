//
//  PrePourCheckView.swift
//  RebarCalc
//
//  Screen 14 — pre-pour checklist. Cover held, laps in place, stirrups tied,
//  starters set. Completing it marks the element pour-ready.
//

import SwiftUI

struct PrePourCheckView: View {
    @EnvironmentObject var store: AppStore
    let elementID: UUID

    private var element: RebarElement? { store.element(elementID) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                if let e = element {
                    let list = e.checklist
                    VStack(spacing: Theme.Space.m) {
                        progressCard(list)
                        Card {
                            VStack(spacing: 4) {
                                checkRow("Concrete cover held", "ruler", list.coverHeld) { toggle(\.coverHeld) }
                                Divider().background(Theme.border)
                                checkRow("Laps in place", "arrow.left.and.right", list.lapsInPlace) { toggle(\.lapsInPlace) }
                                Divider().background(Theme.border)
                                checkRow("Stirrups / ties tied", "link", list.stirrupsTied) { toggle(\.stirrupsTied) }
                                Divider().background(Theme.border)
                                checkRow("Starter bars for next pour", "arrow.up.to.line", list.startersSet) { toggle(\.startersSet) }
                            }
                        }
                        if list.allDone {
                            Card(glow: Theme.ok.opacity(0.4)) {
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 26)).foregroundColor(Theme.ok)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Pour-ready").font(Theme.heading(16)).foregroundColor(Theme.text)
                                        Text("All checks complete for \(e.name).")
                                            .font(Theme.caption(12)).foregroundColor(Theme.textSecond)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(Theme.Space.m)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarTitle("Pre-Pour Check", displayMode: .inline)
    }

    private func progressCard(_ list: PrePourChecklist) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Readiness").font(Theme.heading(16)).foregroundColor(Theme.text)
                    Spacer()
                    Text("\(list.doneCount)/4").font(Theme.numeric(16, weight: .bold))
                        .foregroundColor(list.allDone ? Theme.ok : Theme.line)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.bgDeep)
                        Capsule()
                            .fill(list.allDone ? Theme.ok : Theme.primary)
                            .frame(width: max(6, geo.size.width * CGFloat(list.doneCount) / 4))
                    }
                }
                .frame(height: 8)
            }
        }
    }

    private func checkRow(_ title: String, _ icon: String, _ done: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: { Haptic.tap(); action() }) {
            HStack(spacing: 12) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(done ? Theme.ok : Theme.textMuted)
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(Theme.line)
                Text(title).font(Theme.body(15)).foregroundColor(Theme.text)
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func toggle(_ key: WritableKeyPath<PrePourChecklist, Bool>) {
        guard var e = element else { return }
        e.checklist[keyPath: key].toggle()
        store.setChecklist(e.checklist, for: elementID)
    }
}
