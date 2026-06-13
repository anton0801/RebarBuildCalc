//
//  BendingScheduleView.swift
//  RebarCalc
//
//  Screen 10 — bending schedule. Bar shapes (straight / L / stirrup), bend
//  angles and leg dimensions for the bending machine.
//

import SwiftUI

struct BendingScheduleView: View {
    @EnvironmentObject var store: AppStore
    let element: RebarElement

    private var bends: [BendShape] { store.calc(element).bends }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Space.m) {
                    if bends.isEmpty {
                        Card { EmptyState(icon: "scribble", title: "No shapes", message: "Add reinforcement to generate the bending schedule.") }
                    } else {
                        ForEach(bends) { shape in
                            bendCard(shape)
                        }
                    }
                }
                .padding(Theme.Space.m)
                .padding(.bottom, 30)
            }
        }
        .navigationBarTitle("Bending Schedule", displayMode: .inline)
    }

    private func bendCard(_ shape: BendShape) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(shape.label).font(Theme.heading(15)).foregroundColor(Theme.text)
                    Spacer()
                    PillTag(text: "Ø\(shape.dia)", color: Theme.steel)
                }
                HStack(spacing: Theme.Space.m) {
                    BendShapeDrawing(form: shape.form)
                        .frame(width: 96, height: 70)
                    VStack(alignment: .leading, spacing: 5) {
                        InfoRow(label: "Form", value: shape.form.rawValue, mono: false)
                        if shape.angle > 0 {
                            InfoRow(label: "Bend angle", value: "\(shape.angle)°")
                        }
                        InfoRow(label: "Cut length", value: Fmt.meters(shape.cutLength), valueColor: Theme.steel)
                        InfoRow(label: "Quantity", value: "× " + Fmt.count(shape.count), valueColor: Theme.line)
                    }
                }
                // legs
                let legs = shape.legsMm.filter { $0 > 0.5 }
                if !legs.isEmpty {
                    Divider().background(Theme.border)
                    HStack(spacing: 6) {
                        Text("LEGS").font(Theme.caption(10)).foregroundColor(Theme.textMuted)
                        ForEach(Array(legs.enumerated()), id: \.offset) { _, leg in
                            Text(Fmt.mmRaw(leg)).font(Theme.numeric(12, weight: .semibold))
                                .foregroundColor(Theme.mono)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(Theme.bgSoft))
                        }
                        Text("mm").font(Theme.caption(10)).foregroundColor(Theme.textMuted)
                    }
                }
            }
        }
    }
}

private struct BendShapeDrawing: View {
    let form: BendForm

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Theme.bgDeep)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
                Path { p in
                    let w = geo.size.width, h = geo.size.height
                    let pad: CGFloat = 16
                    switch form {
                    case .straight:
                        p.move(to: CGPoint(x: pad, y: h / 2))
                        p.addLine(to: CGPoint(x: w - pad, y: h / 2))
                    case .lShape:
                        p.move(to: CGPoint(x: pad, y: pad))
                        p.addLine(to: CGPoint(x: pad, y: h - pad))
                        p.addLine(to: CGPoint(x: w - pad, y: h - pad))
                    case .stirrup:
                        p.addRect(CGRect(x: pad, y: pad, width: w - pad * 2, height: h - pad * 2))
                        // hook
                        p.move(to: CGPoint(x: w - pad, y: pad))
                        p.addLine(to: CGPoint(x: w - pad - 10, y: pad + 10))
                    }
                }
                .stroke(form == .stirrup ? Theme.attention : Theme.steel,
                        style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
