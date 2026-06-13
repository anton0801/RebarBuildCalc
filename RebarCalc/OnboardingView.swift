//
//  OnboardingView.swift
//  RebarCalc
//
//  Four interactive pages. Each has its own illustrated scene and a distinct
//  gesture: tap-to-select (1), drag-to-size (2), slider scrub (3), steppers (4).
//  Choices seed the new-element defaults and project lap/cover settings.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    let onComplete: () -> Void

    @AppStorage("prefElement") private var prefElement = ElementType.slab.rawValue
    @AppStorage("prefMainDia") private var prefMainDia = 12
    @AppStorage("prefSpacing") private var prefSpacing = 200.0

    @State private var page = 0
    @State private var elementType: ElementType = .slab
    @State private var mainDia: Int = 12
    @State private var spacing: Double = 200
    @State private var lapDia: Double = 40
    @State private var cover: Double = 30

    var body: some View {
        ZStack {
            RebarBackground(animated: true)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") { finish() }
                        .font(Theme.caption(14))
                        .foregroundColor(Theme.textSecond)
                        .padding(.horizontal, Theme.Space.m)
                        .padding(.top, Theme.Space.m)
                }

                TabView(selection: $page) {
                    ElementPage(selected: $elementType).tag(0)
                    DiameterPage(dia: $mainDia).tag(1)
                    SpacingPage(spacing: $spacing).tag(2)
                    LapCoverPage(lapDia: $lapDia, cover: $cover).tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)

                HStack(spacing: 8) {
                    ForEach(0..<4) { i in
                        Capsule()
                            .fill(i == page ? Theme.primary : Theme.border)
                            .frame(width: i == page ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: page)
                    }
                }
                .padding(.vertical, 14)

                HStack(spacing: 12) {
                    if page > 0 {
                        SecondaryButton(title: "Back", systemImage: "arrow.left") {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { page -= 1 }
                        }
                        .frame(width: 120)
                    }
                    PrimaryButton(title: primaryTitle, systemImage: page == 3 ? "function" : "arrow.right") {
                        advance()
                    }
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.bottom, Theme.Space.l)
            }
        }
    }

    private var primaryTitle: String {
        switch page {
        case 0: return "Set Element"
        case 1: return "Set Bars"
        case 2: return "Set Spacing"
        default: return "Start Calc"
        }
    }

    private func advance() {
        if page < 3 {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { page += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        prefElement = elementType.rawValue
        prefMainDia = mainDia
        prefSpacing = spacing
        var s = store.settings
        s.defaultLapDia = lapDia
        s.defaultCover = cover
        store.updateSettings(s)
        Haptic.success()
        onComplete()
    }
}

// MARK: - Page 1: Element (tap to select, spark burst)

private struct ElementPage: View {
    @Binding var selected: ElementType

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Theme.Space.l) {
                OnboardHeader(icon: "square.grid.3x3.fill",
                              title: "Element",
                              subtitle: "Pick what you're reinforcing. It sets the bar scheme and which results you'll see.")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(ElementType.allCases) { type in
                        ElementSelectCard(type: type, selected: selected == type) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { selected = type }
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.l)
            }
            .padding(.top, Theme.Space.m)
            .padding(.bottom, 40)
        }
    }
}

private struct ElementSelectCard: View {
    let type: ElementType
    let selected: Bool
    let action: () -> Void
    @State private var spark: CGFloat = 0

    var body: some View {
        Button(action: {
            Haptic.tap()
            spark = 1
            withAnimation(.easeOut(duration: 0.55)) { spark = 0 }
            action()
        }) {
            VStack(spacing: 10) {
                ZStack {
                    // spark burst — fires outward and fades on tap
                    ForEach(0..<8) { i in
                        Capsule()
                            .fill(Theme.steel)
                            .frame(width: 3, height: 10)
                            .offset(y: -14 - (1 - spark) * 20)
                            .rotationEffect(.degrees(Double(i) / 8 * 360))
                            .opacity(Double(spark))
                    }
                    Image(systemName: type.icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(selected ? Theme.primary : Theme.textSecond)
                        .scaleEffect(selected ? 1.08 : 1)
                }
                .frame(height: 50)
                Text(type.short)
                    .font(Theme.heading(15))
                    .foregroundColor(selected ? Theme.text : Theme.textSecond)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Space.m)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.m)
                    .fill(selected ? Theme.cardHover : Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m)
                        .stroke(selected ? Theme.primary : Theme.border, lineWidth: selected ? 2 : 1))
            )
            .shadow(color: selected ? Theme.blueGlow : .clear, radius: 10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Page 2: Bar diameter (drag to size)

private struct DiameterPage: View {
    @Binding var dia: Int
    private let sizes = BarSize.onboarding
    @State private var dragX: CGFloat = 0

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            OnboardHeader(icon: "circle.circle.fill",
                          title: "Bar Diameter",
                          subtitle: "Drag the steel bar to thickness — it drives mass per metre and lap length.")

            // draggable steel bar
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Theme.bgDeep)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))

                    Capsule()
                        .fill(Theme.steelGradient)
                        .frame(width: geo.size.width - 60, height: CGFloat(dia) * 2.0)
                        .shadow(color: Theme.steelGlow, radius: 10)
                        .overlay(
                            Text("Ø\(dia)")
                                .font(Theme.numeric(18, weight: .heavy))
                                .foregroundColor(.white)
                        )
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            let frac = max(0, min(1, v.location.x / geo.size.width))
                            let idx = Int((frac * CGFloat(sizes.count - 1)).rounded())
                            let newDia = sizes[max(0, min(sizes.count - 1, idx))]
                            if newDia != dia { Haptic.select(); dia = newDia }
                        }
                )
            }
            .frame(height: 120)
            .padding(.horizontal, Theme.Space.l)

            HStack(spacing: 8) {
                ForEach(sizes, id: \.self) { s in
                    Chip(title: "Ø\(s)", selected: dia == s, accent: Theme.steel) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { dia = s }
                    }
                }
            }
            .padding(.horizontal, Theme.Space.l)

            Card {
                InfoRow(label: "Mass per metre", value: Fmt.kg(BarSize.kgPerMeter(dia)), valueColor: Theme.steel)
                InfoRow(label: "Section area", value: Fmt.num(BarSize.area(dia), digits: 0) + " mm²")
            }
            .padding(.horizontal, Theme.Space.l)

            Spacer()
        }
        .padding(.top, Theme.Space.m)
    }
}

// MARK: - Page 3: Spacing (slider scrub, live mesh)

private struct SpacingPage: View {
    @Binding var spacing: Double

    private var cols: Int { max(2, Int(2000 / spacing)) }
    private var rows: Int { max(2, Int(1400 / spacing)) }

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            OnboardHeader(icon: "ruler.fill",
                          title: "Spacing",
                          subtitle: "Scrub the bar pitch. Tighter spacing means more bars — watch the mesh fill in.")

            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.bgDeep)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.border, lineWidth: 1))
                MeshLines(cols: cols, rows: rows, horizontal: false)
                    .stroke(Theme.line.opacity(0.6), lineWidth: 1.5)
                    .padding(20)
                MeshLines(cols: cols, rows: rows, horizontal: true)
                    .stroke(Theme.lineSoft.opacity(0.5), lineWidth: 1.5)
                    .padding(20)
            }
            .frame(height: 180)
            .padding(.horizontal, Theme.Space.l)
            .animation(.easeInOut(duration: 0.2), value: cols)

            VStack(spacing: 6) {
                Text("\(Int(spacing)) mm")
                    .font(Theme.numeric(26, weight: .heavy)).foregroundColor(Theme.primary)
                Slider(value: $spacing, in: 100...350, step: 10)
                    .accentColor(Theme.primary)
                    .onChange(of: spacing) { _ in Haptic.select() }
                HStack {
                    Text("100").font(Theme.caption(11)).foregroundColor(Theme.textMuted)
                    Spacer()
                    Text("350 mm").font(Theme.caption(11)).foregroundColor(Theme.textMuted)
                }
            }
            .padding(.horizontal, Theme.Space.l)

            Spacer()
        }
        .padding(.top, Theme.Space.m)
    }
}

// MARK: - Page 4: Lap & cover (steppers)

private struct LapCoverPage: View {
    @Binding var lapDia: Double
    @Binding var cover: Double

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            OnboardHeader(icon: "arrow.left.and.right",
                          title: "Lap & Cover",
                          subtitle: "Lap length sets splice metres; cover sets the cage size inside the concrete.")

            // cover diagram
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.bgDeep)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.border, lineWidth: 1))
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.line.opacity(0.6), lineWidth: 2)
                    .padding(CGFloat(cover) / 2 + 18)
                    .overlay(
                        Text("cover \(Int(cover)) mm")
                            .font(Theme.caption(11)).foregroundColor(Theme.textSecond)
                            .offset(y: -8), alignment: .top)
            }
            .frame(height: 150)
            .padding(.horizontal, Theme.Space.l)
            .animation(.easeInOut(duration: 0.2), value: cover)

            VStack(spacing: 14) {
                LabeledStepper(title: "Lap length (× diameter)", value: $lapDia, step: 5,
                               minValue: 20, maxValue: 60, unit: "× d")
                LabeledStepper(title: "Concrete cover", value: $cover, step: 5,
                               minValue: 15, maxValue: 75, unit: "mm")
            }
            .padding(.horizontal, Theme.Space.l)

            Spacer()
        }
        .padding(.top, Theme.Space.m)
    }
}

// MARK: - Shared header

private struct OnboardHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(Theme.primary)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Theme.primary.opacity(0.15)))
            Text(title).font(Theme.title(26)).foregroundColor(Theme.text)
            Text(subtitle)
                .font(Theme.body(14)).foregroundColor(Theme.textSecond)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Space.l)
        }
        .padding(.horizontal, Theme.Space.m)
    }
}
