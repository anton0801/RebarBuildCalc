//
//  SplashView.swift
//  RebarCalc
//
//  Themed launch animation: a rebar slab mesh assembles from blue lines while an
//  orange rust glint runs along the bars; the logo and title spring in; the cage
//  scales up and fades on exit. Single Timer coordinator, all loops reset on exit.
//

import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void

    // staged reveal flags
    @State private var showGrid = false
    @State private var drawMesh: CGFloat = 0
    @State private var showLogo = false
    @State private var showTitle = false
    @State private var exiting = false

    // looping flags
    @State private var glint: CGFloat = 0
    @State private var nodePulse = false
    @State private var glowPulse = false

    // coordinator
    @State private var isVisible = true
    @State private var elapsed: Double = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            // ---- Layer 1: background gradient + faint grid ----
            Theme.background.ignoresSafeArea()

            GeometryReader { geo in
                RebarGrid(spacing: 42)
                    .stroke(Theme.line.opacity(showGrid ? 0.07 : 0), lineWidth: 0.8)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .ignoresSafeArea()

            // ---- Layer 2: assembling slab mesh + travelling glint ----
            ZStack {
                MeshLines(cols: 7, rows: 5, horizontal: false)
                    .trim(from: 0, to: drawMesh)
                    .stroke(Theme.line.opacity(0.55),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .shadow(color: Color(hex: 0x38BDF8, alpha: 0.30), radius: 5)
                MeshLines(cols: 7, rows: 5, horizontal: true)
                    .trim(from: 0, to: drawMesh)
                    .stroke(Theme.lineSoft.opacity(0.45),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round))

                // orange rust glint running along the horizontal bars
                MeshLines(cols: 7, rows: 5, horizontal: true)
                    .trim(from: glint * 0.82, to: glint * 0.82 + 0.18)
                    .stroke(Theme.steel,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .shadow(color: Theme.steelGlow, radius: 9)
                    .opacity(drawMesh >= 1 ? 1 : 0)
            }
            .frame(width: 250, height: 180)
            .scaleEffect(exiting ? 1.6 : 1)
            .opacity(exiting ? 0 : 1)

            // ---- Layer 3: logo + title ----
            VStack(spacing: 18) {
                LogoMark(pulse: nodePulse, glow: glowPulse)
                    .frame(width: 96, height: 96)
                    .scaleEffect(showLogo ? (exiting ? 1.5 : 1) : 0.4)
                    .opacity(showLogo ? (exiting ? 0 : 1) : 0)

                VStack(spacing: 6) {
                    Text("REBAR CALC")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .tracking(3)
                        .foregroundColor(Theme.text)
                    Text("Count the steel before the pour.")
                        .font(Theme.caption(13))
                        .foregroundColor(Theme.textSecond)
                }
                .opacity(showTitle ? (exiting ? 0 : 1) : 0)
                .offset(y: showTitle ? 0 : 12)
            }
            .offset(y: 12)
        }
        .onAppear { start() }
        .onDisappear { teardown() }
    }

    // MARK: - Coordinator

    private func start() {
        isVisible = true
        withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { glint = 1 }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { nodePulse = true }
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { glowPulse = true }

        elapsed = 0
        let t = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            elapsed += 0.05
            tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard isVisible else { return }
        if elapsed >= 0.1 && !showGrid {
            withAnimation(.easeOut(duration: 0.6)) { showGrid = true }
        }
        if elapsed >= 0.5 && drawMesh == 0 {
            withAnimation(.easeInOut(duration: 1.0)) { drawMesh = 1 }
        }
        if elapsed >= 1.4 && !showLogo {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { showLogo = true }
        }
        if elapsed >= 1.9 && !showTitle {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { showTitle = true }
        }
        if elapsed >= 2.5 && !exiting {
            withAnimation(.easeIn(duration: 0.45)) { exiting = true }
        }
        if elapsed >= 2.95 {
            timer?.invalidate(); timer = nil
            onFinish()
        }
    }

    private func teardown() {
        isVisible = false
        timer?.invalidate(); timer = nil
        // reset every loop / stage flag to prevent background animation leaks
        glint = 0
        nodePulse = false
        glowPulse = false
        showGrid = false
        drawMesh = 0
        showLogo = false
        showTitle = false
        exiting = false
    }
}

// MARK: - Logo mark

private struct LogoMark: View {
    var pulse: Bool
    var glow: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.primary.opacity(0.6), lineWidth: 2))
                .shadow(color: Theme.blueGlow, radius: glow ? 16 : 8)

            // small blue mesh
            MeshLines(cols: 3, rows: 3, horizontal: false)
                .stroke(Theme.line.opacity(0.55), lineWidth: 2)
                .padding(20)
            MeshLines(cols: 3, rows: 3, horizontal: true)
                .stroke(Theme.lineSoft.opacity(0.45), lineWidth: 2)
                .padding(20)

            // orange diagonal steel bar
            DiagonalBar()
                .stroke(Theme.steelGradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .padding(20)
                .shadow(color: Theme.steelGlow, radius: glow ? 10 : 5)
        }
        .scaleEffect(pulse ? 1.04 : 0.97)
    }
}

private struct DiagonalBar: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}
