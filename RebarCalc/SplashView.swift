import SwiftUI
import Combine
import Network

struct SplashView: View {
    
    @State private var networkMonitor = NWPathMonitor()
    
    // MARK: Perpetual loop drivers (toggled inside .repeatForever, reset on exit)
    @State private var ringSpin: CGFloat = 0       // 0 -> 1  == full 360° rotation of the arc
    @State private var needleSweep = false         // gauge needle back/forth
    @State private var sparkPulse = false          // weld spark flicker (scale + glow)
    @State private var corePulse = false           // hex-bolt breathing glow
    @State private var gridBreath = false          // blueprint grid faint pulse
    @State private var scan: CGFloat = 0           // masked scan-sweep across the wordmark
    @State private var calloutPulse = false        // technical callout soft-pulse
    @State private var bubble: CGFloat = 0         // spirit-level bubble drift (-1…+1)
    @State private var groupBreath = false         // slow ambient parallax breathe
    
    @StateObject private var deck = Deck()

    // MARK: Staged intro flags (driven by a Timer that stops after the intro)
    @State private var showGrid = false
    @State private var assemble: CGFloat = 0        // 0 -> 1  ring draws itself on
    @State private var showCore = false
    @State private var showTitle = false
    
    @State private var cancellables = Set<AnyCancellable>()
    
    // MARK: Coordinator (one-shot intro only; guarded + invalidated on teardown)
    @State private var isVisible = true
    @State private var timer: Timer?

    private let ringSize: CGFloat = 208

    // Fixed angular positions (fraction of a full turn, 0 = 12 o'clock) of the
    // three weld-nodes seated on the guide-ring track.
    private let nodePhases: [CGFloat] = [0.12, 0.42, 0.74]

    var body: some View {
        NavigationView {
            GeometryReader { geo in
                ZStack {
                    // ---- Layer 1: background gradient ----
                    Color.black.ignoresSafeArea()
                    
                    Image(geo.size.width > geo.size.height ? "clouds_loading_sec" : "clouds_loading")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .ignoresSafeArea()
                        .opacity(0.75)
                        .blur(radius: 2.1)

                    // ---- Layer 2: faint blueprint grid ----
                    GeometryReader { geo in
                        RebarGrid(spacing: 40)
                            .stroke(Theme.line.opacity(showGrid ? (gridBreath ? 0.09 : 0.05) : 0),
                                    lineWidth: 0.8)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                    .ignoresSafeArea()
                    
                    NavigationLink(
                        destination: SlabView().navigationBarHidden(true),
                        isActive: $deck.navigateToWeb
                    ) { EmptyView() }

                    // ---- Layer 3: the loader ring + central gauge (with ambient breathe) ----
                    SplashLoaderRing(
                        spin: ringSpin,
                        assemble: assemble,
                        showCore: showCore,
                        needleSweep: needleSweep,
                        sparkPulse: sparkPulse,
                        corePulse: corePulse,
                        nodePhases: nodePhases,
                        nodeGlow: { nodeGlow(for: $0) }
                    )
                    .frame(width: ringSize, height: ringSize)
                    // Very slow, tiny parallax breathe so the perpetual state never feels frozen.
                    .scaleEffect(groupBreath ? 1.02 : 0.99)
                    .offset(y: -46)

                    // ---- Layer 4: engineering callouts + spirit level (secondary instruments) ----
                    SplashInstruments(
                        show: showCore,
                        calloutPulse: calloutPulse,
                        bubble: bubble,
                        dialValue: dialReadout
                    )
                    .frame(width: ringSize + 96, height: ringSize + 40)
                    .offset(y: -46)
                    
                    NavigationLink(
                        destination: RootView().navigationBarBackButtonHidden(true),
                        isActive: $deck.navigateToMain
                    ) { EmptyView() }

                    // ---- Layer 5: wordmark + tagline (with masked scan-sweep) ----
                    VStack(spacing: 6) {
                        SplashWordmark(scan: scan)
                        Text("Loading application content.")
                            .font(Theme.caption(13))
                            .foregroundColor(Theme.textSecond)
                    }
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? (ringSize / 2 + 40) : (ringSize / 2 + 52))
                }
                .fullScreenCover(isPresented: $deck.showPermissionPrompt) {
                    ConsentPour(deck: deck)
                }
                .onAppear { start() }
                .onDisappear { teardown() }
                .fullScreenCover(isPresented: $deck.showOfflineView) {
                    OfflinePour()
                }
            }
            .ignoresSafeArea()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Derived values

    /// Continuous, smoothly-ramped ignition brightness (0…1) for a weld-node at a
    /// given angular phase. Uses wrap-around distance to the rotating spark tip and
    /// an opacity ramp `max(0, 1 - dist / window)` — NO boolean threshold, so nodes
    /// bloom and settle without popping.
    private func nodeGlow(for phase: CGFloat) -> CGFloat {
        // The spark rides the leading tip of the arc, which sits `arcFraction` ahead
        // of the rotation origin. Match SplashLoaderRing.arcFraction (0.66).
        let tip = (ringSpin + 0.66).truncatingRemainder(dividingBy: 1)
        let raw = abs(tip - phase)
        let dist = min(raw, 1 - raw)          // wrap-around angular distance (0…0.5)
        let window: CGFloat = 0.12            // how close before a node lights
        return max(0, 1 - dist / window)      // smooth crossfade ramp
    }

    /// A live-feeling numeric readout that tracks the needle sweep, shown in a pill.
    private var dialReadout: Int {
        // needleSweep animates false↔true (0↔1) via easeInOut; map to a plausible
        // spacing value so it reads like a working instrument.
        Int((needleSweep ? 300 : 150).rounded())
    }

    private func wireStreams() {
        NotificationCenter.default.publisher(for: .barsArrived)
            .compactMap { $0.userInfo?["conversionData"] as? [String: Any] }
            .sink { data in
                deck.ingestBars(data)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .lapsArrived)
            .compactMap { $0.userInfo?["deeplinksData"] as? [String: Any] }
            .sink { data in
                deck.ingestLaps(data)
            }
            .store(in: &cancellables)
    }
    // MARK: - Coordinator

    private func start() {
        isVisible = true

        // Perpetual ambient loops — these run forever until teardown().
        withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
            ringSpin = 1
        }
        withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
            needleSweep = true
        }
        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
            sparkPulse = true
        }
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            corePulse = true
        }
        withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
            gridBreath = true
        }
        deck.ignite()
        // Scan-sweep: .linear no-autoreverse so the wordmark shimmer loops seamlessly.
        withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
            scan = 1
        }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            calloutPulse = true
        }
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
            bubble = 1
        }
        withAnimation(.easeInOut(duration: 4.4).repeatForever(autoreverses: true)) {
            groupBreath = true
        }
        wireNetworkMonitoring()

        // Staged one-time intro. The Timer only sequences the reveal, then stops.
        // It NEVER calls onFinish — the ambient loops above keep running forever.
        // `elapsed` is a LOCAL captured by the closure (no needless view re-render
        // on every 0.05s tick); the timer self-invalidates once the intro is done.
        var elapsed: Double = 0
        let t = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard isVisible else { return }
            elapsed += 0.05

            if elapsed >= 0.10 && !showGrid {
                withAnimation(.easeOut(duration: 0.7)) { showGrid = true }
            }
            if elapsed >= 0.35 && assemble == 0 {
                withAnimation(.easeInOut(duration: 0.9)) { assemble = 1 }
            }
            if elapsed >= 0.95 && !showCore {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.62)) { showCore = true }
            }
            if elapsed >= 1.25 && !showTitle {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { showTitle = true }
            }
            // Intro finished — stop the Timer. The ambient loops keep the view alive.
            if elapsed >= 1.7 {
                timer?.invalidate()
                timer = nil
            }
        }
        wireStreams()
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    
    private func wireNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { path in
            Task { @MainActor in
                deck.networkConnectivityChanged(path.status == .satisfied)
            }
        }
        networkMonitor.start(queue: .global(qos: .background))
    }

    private func teardown() {
        // Guard all ticks, kill the Timer, and reset every repeating driver to
        // its base value WITHOUT animation so no .repeatForever survives offscreen.
        isVisible = false
        timer?.invalidate()
        timer = nil

        ringSpin = 0
        needleSweep = false
        sparkPulse = false
        corePulse = false
        gridBreath = false
        scan = 0
        calloutPulse = false
        bubble = 0
        groupBreath = false

        showGrid = false
        assemble = 0
        showCore = false
        showTitle = false
    }
}

// MARK: - Loader ring assembly (arc + trailing glow + spark + weld-nodes + gauge)

private struct SplashLoaderRing: View {
    var spin: CGFloat        // 0...1 mapped to 0...360°
    var assemble: CGFloat    // 0...1 intro draw-on of the arc
    var showCore: Bool       // gauge reveal
    var needleSweep: Bool
    var sparkPulse: Bool
    var corePulse: Bool
    var nodePhases: [CGFloat]
    var nodeGlow: (CGFloat) -> CGFloat   // continuous 0…1 ignition per node phase

    // The arc occupies this fraction of the circle; the rest is the loader gap.
    private let arcFraction: CGFloat = 0.66
    private let inset: CGFloat = 6

    private var rotation: Angle { .degrees(Double(spin) * 360) }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let radius = side / 2 - inset
            let lineWidth = side * 0.052
            // Leading tip of the drawn arc, in ring-local coordinates, before rotation.
            let tip = tipPoint(radius: radius, center: side / 2)

            ZStack {
                // Static faint guide ring (the "track" the loader runs on)
                Circle()
                    .stroke(Theme.line.opacity(0.10), lineWidth: 1)
                    .padding(inset)

                // Weld-nodes seated on the guide-ring track. These do NOT rotate; the
                // spark ignites each as it sweeps past (continuous crossfade ramp).
                ForEach(Array(nodePhases.enumerated()), id: \.offset) { _, phase in
                    SplashWeldNode(glow: nodeGlow(phase))
                        .position(nodePoint(phase: phase, radius: radius, center: side / 2))
                        .opacity(assemble >= 0.98 ? 1 : 0)
                }

                // --- Rotating group: trailing glow, ribbed rebar arc, weld spark ---
                ZStack {
                    // Soft trailing glow behind the bar (fades toward the tail)
                    SplashArc(fraction: arcFraction * assemble)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Theme.steel.opacity(0.0),
                                    Theme.steel.opacity(0.10),
                                    Theme.steelGlow,
                                    Theme.steel.opacity(0.55)
                                ]),
                                center: .center,
                                angle: .degrees(-90)
                            ),
                            style: StrokeStyle(lineWidth: lineWidth * 1.9, lineCap: .round)
                        )
                        .blur(radius: 7)
                        .opacity(0.9)

                    // Cyan-blue schematic under-stroke (the bent structural line)
                    SplashArc(fraction: arcFraction * assemble)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Theme.line.opacity(0.0),
                                    Theme.line.opacity(0.35),
                                    Theme.lineSoft.opacity(0.55)
                                ]),
                                center: .center,
                                angle: .degrees(-90)
                            ),
                            style: StrokeStyle(lineWidth: lineWidth + 2, lineCap: .round)
                        )

                    // Main steel rebar body — hot toward the leading tip
                    SplashArc(fraction: arcFraction * assemble)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Theme.steel.opacity(0.30),
                                    Theme.steel,
                                    Theme.steelHi
                                ]),
                                center: .center,
                                angle: .degrees(-90)
                            ),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )

                    // Ribs (rebar deformations) crossing the bar, clipped to the bar body
                    SplashRibs(fraction: arcFraction * assemble, ribCount: 26)
                        .stroke(Theme.bgDeep.opacity(0.45),
                                style: StrokeStyle(lineWidth: 1.4, lineCap: .butt))
                        .mask(
                            SplashArc(fraction: arcFraction * assemble)
                                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        )

                    // Hot weld spark at the leading tip
                    SplashWeldSpark(pulse: sparkPulse)
                        .frame(width: lineWidth * 2.1, height: lineWidth * 2.1)
                        .position(tip)
                        .opacity(assemble >= 0.98 ? 1 : 0)
                }
                .rotationEffect(rotation)

                // --- Central engineering gauge (does NOT rotate with the ring) ---
                SplashGauge(needleSweep: needleSweep, corePulse: corePulse)
                    .frame(width: side * 0.42, height: side * 0.42)
                    .scaleEffect(showCore ? 1 : 0.4)
                    .opacity(showCore ? 1 : 0)
            }
        }
    }

    /// Leading-tip position of the arc (angle where the trimmed arc ends),
    /// in the ring's local coordinate space, before rotation is applied.
    private func tipPoint(radius: CGFloat, center: CGFloat) -> CGPoint {
        // SplashArc starts at the top (-90°) and sweeps clockwise by `arcFraction`.
        let sweep = Double(arcFraction) * 360.0
        let angle = Angle.degrees(-90 + sweep).radians
        return CGPoint(x: center + radius * CGFloat(cos(angle)),
                       y: center + radius * CGFloat(sin(angle)))
    }

    /// Fixed position of a weld-node at `phase` (0…1 of a full turn from 12 o'clock).
    private func nodePoint(phase: CGFloat, radius: CGFloat, center: CGFloat) -> CGPoint {
        let angle = Angle.degrees(-90 + Double(phase) * 360).radians
        return CGPoint(x: center + radius * CGFloat(cos(angle)),
                       y: center + radius * CGFloat(sin(angle)))
    }
}

// MARK: - Weld node (ignited by the passing spark)

/// A small cyan dot on the guide-ring that flares cyan→orange as the spark passes.
/// `glow` is a continuous 0…1 ignition amount driven by an angular distance ramp,
/// so the bloom crossfades smoothly with no boolean pop.
private struct SplashWeldNode: View {
    var glow: CGFloat   // 0 = dormant cyan, 1 = fully ignited hot

    var body: some View {
        let g = max(0, min(1, glow))
        // Colour crosses cyan → orange as it ignites.
        let core = Color(
            hex: g > 0.5 ? 0xFB9D5C : 0x38BDF8,
            alpha: 1
        )
        ZStack {
            // Outer bloom that only appears with ignition.
            Circle()
                .fill(Theme.steel.opacity(0.42 * Double(g)))
                .frame(width: 6 + 10 * g, height: 6 + 10 * g)
                .blur(radius: 2)

            // Node core.
            Circle()
                .fill(core)
                .frame(width: 4 + 2.5 * g, height: 4 + 2.5 * g)
                .shadow(color: g > 0.4 ? Theme.steelGlow : Theme.blueGlow,
                        radius: 2 + 6 * g)
        }
        .opacity(0.55 + 0.45 * Double(g))
    }
}

// MARK: - Arc shape (top-anchored, clockwise, trimmable)

private struct SplashArc: Shape {
    /// Portion of the full circle drawn, 0...1. Starts at 12 o'clock, clockwise.
    var fraction: CGFloat

    var animatableData: CGFloat {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let clamped = max(0, min(1, fraction))
        let start = Angle.degrees(-90)
        let end = Angle.degrees(-90 + Double(clamped) * 360)
        p.addArc(center: center, radius: r, startAngle: start, endAngle: end, clockwise: false)
        return p
    }
}

// MARK: - Ribs across the bar (rebar deformation ticks)

private struct SplashRibs: Shape {
    var fraction: CGFloat
    var ribCount: Int

    var animatableData: CGFloat {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let sweep = Double(max(0, min(1, fraction))) * 360.0
        guard ribCount > 0, sweep > 0 else { return p }

        // Distribute ticks along the drawn arc; angle them for a "forged" look.
        let step = sweep / Double(ribCount)
        let tick = r * 0.16     // half-length of each rib crossing the bar
        var a = step * 0.5
        while a <= sweep {
            let ang = (-90 + a) * .pi / 180
            let px = center.x + r * CGFloat(cos(ang))
            let py = center.y + r * CGFloat(sin(ang))
            // Rib is a short segment skewed relative to the radial direction.
            let skew = ang + 0.45
            let dx = tick * CGFloat(cos(skew))
            let dy = tick * CGFloat(sin(skew))
            p.move(to: CGPoint(x: px - dx, y: py - dy))
            p.addLine(to: CGPoint(x: px + dx, y: py + dy))
            a += step
        }
        return p
    }
}

// MARK: - Weld spark (hot leading tip)

private struct SplashWeldSpark: View {
    var pulse: Bool

    var body: some View {
        ZStack {
            // outer heat bloom
            Circle()
                .fill(Theme.steelHi.opacity(pulse ? 0.55 : 0.28))
                .blur(radius: pulse ? 8 : 5)
                .scaleEffect(pulse ? 1.35 : 0.95)

            // molten core
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.white, Theme.steelHi, Theme.steel]),
                        center: .center, startRadius: 0, endRadius: 9
                    )
                )
                .frame(width: 12, height: 12)
                .shadow(color: Theme.steelGlow, radius: pulse ? 10 : 6)

            // four-point sparkle spikes
            SplashSparkle()
                .stroke(Theme.steelHi.opacity(pulse ? 0.9 : 0.5),
                        style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                .scaleEffect(pulse ? 1.15 : 0.8)
                .opacity(pulse ? 1 : 0.6)
        }
    }
}

private struct SplashSparkle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let len = min(rect.width, rect.height) / 2
        // vertical + horizontal spikes
        p.move(to: CGPoint(x: c.x, y: c.y - len)); p.addLine(to: CGPoint(x: c.x, y: c.y + len))
        p.move(to: CGPoint(x: c.x - len, y: c.y)); p.addLine(to: CGPoint(x: c.x + len, y: c.y))
        return p
    }
}

// MARK: - Central engineering gauge (hex bolt + sweeping needle)

private struct SplashGauge: View {
    var needleSweep: Bool
    var corePulse: Bool

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let c = CGPoint(x: side / 2, y: side / 2)

            ZStack {
                // Hex-bolt seat
                SplashHexagon()
                    .fill(Theme.card)
                    .overlay(
                        SplashHexagon()
                            .stroke(Theme.primary.opacity(0.55), lineWidth: 2)
                    )
                    .shadow(color: Theme.blueGlow, radius: corePulse ? 14 : 8)

                // Inner dial ring
                Circle()
                    .stroke(Theme.line.opacity(0.30), lineWidth: 1)
                    .padding(side * 0.16)

                // Gauge tick marks around the dial
                SplashGaugeTicks(count: 12)
                    .stroke(Theme.lineSoft.opacity(0.45),
                            style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                    .padding(side * 0.11)

                // Sweeping needle (an orange steel pointer)
                SplashNeedle()
                    .fill(Theme.steelGradient)
                    .frame(width: side * 0.5, height: side * 0.5)
                    .shadow(color: Theme.steelGlow, radius: 4)
                    // sweep across a 116° fan, centred at 12 o'clock
                    .rotationEffect(.degrees(needleSweep ? 58 : -58))

                // Center pivot cap
                Circle()
                    .fill(Theme.steel)
                    .frame(width: side * 0.14, height: side * 0.14)
                    .overlay(
                        Circle().stroke(Theme.steelHi, lineWidth: 1)
                    )
                    .position(c)
            }
        }
    }
}

private struct SplashHexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for i in 0..<6 {
            // flat-top hex: start at -90° so a flat edge sits up top
            let ang = (Double(i) * 60.0 - 90.0) * .pi / 180
            let pt = CGPoint(x: c.x + r * CGFloat(cos(ang)),
                             y: c.y + r * CGFloat(sin(ang)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

private struct SplashGaugeTicks: Shape {
    var count: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.82
        guard count > 0 else { return p }
        for i in 0..<count {
            let ang = (Double(i) * (360.0 / Double(count)) - 90.0) * .pi / 180
            let ca = CGFloat(cos(ang)); let sa = CGFloat(sin(ang))
            p.move(to: CGPoint(x: c.x + inner * ca, y: c.y + inner * sa))
            p.addLine(to: CGPoint(x: c.x + outer * ca, y: c.y + outer * sa))
        }
        return p
    }
}

private struct SplashNeedle: Shape {
    func path(in rect: CGRect) -> Path {
        // A slim tapered pointer from center up to near the top of the frame.
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let tipY = rect.minY + rect.height * 0.06
        let baseHalf = rect.width * 0.045
        let tailY = c.y + rect.height * 0.10
        p.move(to: CGPoint(x: c.x, y: tipY))
        p.addLine(to: CGPoint(x: c.x + baseHalf, y: c.y))
        p.addLine(to: CGPoint(x: c.x, y: tailY))
        p.addLine(to: CGPoint(x: c.x - baseHalf, y: c.y))
        p.closeSubpath()
        return p
    }
}

// MARK: - Secondary instruments (technical callouts + spirit-level bubble)

/// Small engineering callouts flanking the gauge plus one spirit-level bubble below,
/// so the loader reads as a real rebar CALCULATOR instrument, not just a spinner.
private struct SplashInstruments: View {
    var show: Bool
    var calloutPulse: Bool
    var bubble: CGFloat      // -1…+1 (arrives as 0…1, remapped below)
    var dialValue: Int

    var body: some View {
        ZStack {
            // Diameter callout — top-right of the gauge.
            SplashCallout(text: "Ø12", accent: true)
                .scaleEffect(calloutPulse ? 1.04 : 1.0)
                .position(x: 62, y: 30)

            // Live-feeling dial readout — bottom-left of the gauge.
            SplashCallout(text: "\(dialValue)", accent: false)
                .scaleEffect(calloutPulse ? 1.04 : 1.0)
                .position(x: 66, y: 118)

            // Spirit-level micro-instrument, centred below the gauge.
            SplashSpiritLevel(bubble: bubble * 2 - 1)   // remap 0…1 → -1…+1
        }
        .opacity(show ? 1 : 0)
        .allowsHitTesting(false)
    }
}

/// A small pill-shaped technical callout label (e.g. "Ø12", "300").
private struct SplashCallout: View {
    var text: String
    var accent: Bool

    var body: some View {
        Text(text)
            .font(Theme.numeric(11, weight: .bold))
            .foregroundColor(accent ? Theme.steelHi : Theme.lineSoft)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Theme.card.opacity(0.92))
                    .overlay(
                        Capsule().stroke(
                            (accent ? Theme.steel : Theme.line).opacity(0.5),
                            lineWidth: 1)
                    )
            )
    }
}

/// A single small green spirit-level bubble drifting left↔right — reinforces the
/// "leveling / measuring" construction-tool metaphor without adding clutter.
private struct SplashSpiritLevel: View {
    var bubble: CGFloat   // -1…+1

    private let vialWidth: CGFloat = 58
    private let vialHeight: CGFloat = 16

    var body: some View {
        ZStack {
            Capsule()
                .fill(Theme.bgSoft.opacity(0.85))
                .overlay(Capsule().stroke(Theme.border.opacity(0.7), lineWidth: 1))

            // Centre reference marks.
            HStack(spacing: 16) {
                Rectangle().fill(Theme.line.opacity(0.5)).frame(width: 1, height: 9)
                Rectangle().fill(Theme.line.opacity(0.5)).frame(width: 1, height: 9)
            }

            // The drifting bubble.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.ok.opacity(0.95), Theme.ok.opacity(0.45)],
                        center: .center, startRadius: 0, endRadius: 7)
                )
                .frame(width: 11, height: 11)
                .shadow(color: Theme.ok.opacity(0.6), radius: 4)
                .offset(x: bubble * (vialWidth / 2 - 9))
        }
        .frame(width: vialWidth, height: vialHeight)
        .position(x: (208 + 96) / 2, y: (208 + 40) / 2 + 78)
    }
}

// MARK: - Wordmark with masked scan-sweep

/// "REBAR CALC" wordmark. A steel-hi gradient band shimmers across it forever,
/// clamped by a Text mask, driven by a .linear 0→1 phase (seamless loop).
private struct SplashWordmark: View {
    var scan: CGFloat   // 0…1 sweep phase

    private let font: Font = .system(size: 30, weight: .heavy, design: .rounded)

    var body: some View {
        Text("REBAR CALC")
            .font(font)
            .foregroundColor(Theme.text)
            .overlay(
                GeometryReader { geo in
                    let w = geo.size.width
                    LinearGradient(
                        colors: [Color.clear, Theme.steelHi.opacity(0.9), Color.clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: w * 0.4)
                    // Travel from fully off the left to fully off the right.
                    .offset(x: -w * 0.7 + scan * (w * 1.4))
                }
                .mask(
                    Text("REBAR CALC")
                        .font(font)
                )
                .allowsHitTesting(false)
            )
    }
}

struct ConsentPour: View {
    let deck: Deck
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image(geometry.size.width > geometry.size.height ? "clouds_rebar_sec" : "clouds_rebar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea().opacity(0.9)
                
                VStack(spacing: 12) {
                    Spacer()
                    Text("ALLOW NOTIFICATIONS ABOUT BONUSES AND PROMOS")
                        .font(.system(size: 23, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .multilineTextAlignment(.center)
                    subtitleText
                    actionButtons
                }
                .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
    
    private var subtitleText: some View {
        Text("STAY TUNED WITH BEST OFFERS FROM OUR CASINO")
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 12)
            .multilineTextAlignment(.center)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                deck.acceptConsent()
            } label: {
                Image("clouds_rebarr")
                    .resizable()
                    .frame(width: 305, height: 56)
            }
            
            Button {
                deck.skipConsent()
            } label: {
                Text("SKIP")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
    }
}

struct OfflinePour: View {
    
    private var name = "cl_error"
    private var nameTwo = "cl_error_sec"
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                Image(geometry.size.width > geometry.size.height ? nameTwo : name)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                    .opacity(0.85)
                    .blur(radius: 2.5)
                
                Image("cl_error_app")
                    .resizable()
                    .frame(width: 240, height: 225)
            }
        }
        .ignoresSafeArea()
    }
    
}
