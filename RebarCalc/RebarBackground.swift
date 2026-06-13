//
//  RebarBackground.swift
//  RebarCalc
//
//  Reusable reinforcement-grid shapes and the animated app background.
//

import SwiftUI

// MARK: - Grid shape (thin blue rebar mesh)

struct RebarGrid: Shape {
    var spacing: CGFloat = 38

    func path(in rect: CGRect) -> Path {
        var p = Path()
        var x: CGFloat = 0
        while x <= rect.width {
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x, y: rect.height))
            x += spacing
        }
        var y: CGFloat = 0
        while y <= rect.height {
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: rect.width, y: y))
            y += spacing
        }
        return p
    }
}

// MARK: - Isometric slab cage (decorative)

struct SlabCage: Shape {
    var cols: Int = 5
    var rows: Int = 4
    var skew: CGFloat = 0.34   // vertical skew factor for the iso look

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        let dx = w / CGFloat(cols)
        let dy = (h * (1 - skew)) / CGFloat(rows)
        let topOffset = h * skew

        // bars running "into" the page (left-to-right), shifted down per row
        for r in 0...rows {
            let y = topOffset + CGFloat(r) * dy * 0.0 + CGFloat(r) * dy
            let yShift = topOffset - CGFloat(r) / CGFloat(rows) * topOffset
            p.move(to: CGPoint(x: 0, y: y - 0))
            p.addLine(to: CGPoint(x: w, y: y - 0))
            _ = yShift
        }
        // cross bars
        for c in 0...cols {
            let x = CGFloat(c) * dx
            p.move(to: CGPoint(x: x, y: topOffset))
            p.addLine(to: CGPoint(x: x, y: h))
        }
        return p
    }
}

/// A flat slab mesh used by the splash assemble animation.
struct MeshLines: Shape {
    var cols: Int = 6
    var rows: Int = 5
    var horizontal: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        if horizontal {
            let dy = rect.height / CGFloat(rows)
            for r in 0...rows {
                let y = CGFloat(r) * dy
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: rect.width, y: y))
            }
        } else {
            let dx = rect.width / CGFloat(cols)
            for c in 0...cols {
                let x = CGFloat(c) * dx
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: rect.height))
            }
        }
        return p
    }
}

// MARK: - App background

struct RebarBackground: View {
    var animated: Bool = false
    @State private var shimmer = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            GeometryReader { geo in
                RebarGrid(spacing: 40)
                    .stroke(Theme.line.opacity(0.06), lineWidth: 0.8)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .overlay(
                        // a soft steel glow sweeping across, when animated
                        Group {
                            if animated {
                                LinearGradient(
                                    colors: [.clear, Theme.steel.opacity(0.07), .clear],
                                    startPoint: .leading, endPoint: .trailing)
                                    .frame(width: geo.size.width * 0.5)
                                    .offset(x: shimmer ? geo.size.width * 0.75 : -geo.size.width * 0.75)
                            }
                        }
                    )
            }
            .ignoresSafeArea()
        }
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: false)) {
                shimmer = true
            }
        }
        .onDisappear { shimmer = false }
    }
}
