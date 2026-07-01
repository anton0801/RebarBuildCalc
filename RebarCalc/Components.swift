//
//  Components.swift
//  RebarCalc
//
//  Reusable, fully-themed UI building blocks. Every interactive element gives
//  haptic feedback and a spring press response.
//

import SwiftUI
import Combine

// MARK: - Haptics

enum Haptic {
    static func tap() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

// MARK: - Buttons

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var enabled: Bool = true
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: {
            guard enabled else { return }
            Haptic.tap()
            action()
        }) {
            HStack(spacing: 8) {
                if let s = systemImage { Image(systemName: s).font(.system(size: 15, weight: .bold)) }
                Text(title).font(Theme.heading(16))
            }
            .foregroundColor(Theme.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.primaryGradient))
            .shadow(color: Theme.blueGlow, radius: pressed ? 4 : 12, x: 0, y: 4)
            .opacity(enabled ? 1 : 0.4)
            .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!enabled)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in withAnimation(.easeOut(duration: 0.12)) { pressed = true } }
            .onEnded { _ in withAnimation(.easeOut(duration: 0.18)) { pressed = false } })
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: { Haptic.light(); action() }) {
            HStack(spacing: 8) {
                if let s = systemImage { Image(systemName: s).font(.system(size: 14, weight: .semibold)) }
                Text(title).font(Theme.heading(15))
            }
            .foregroundColor(Theme.onSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.m)
                    .fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.border, lineWidth: 1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DangerButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: { Haptic.warning(); action() }) {
            HStack(spacing: 8) {
                if let s = systemImage { Image(systemName: s).font(.system(size: 14, weight: .semibold)) }
                Text(title).font(Theme.heading(15))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.error))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Card

struct Card<Content: View>: View {
    var padding: CGFloat = Theme.Space.m
    var glow: Color? = nil
    let content: () -> Content

    init(padding: CGFloat = Theme.Space.m, glow: Color? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.glow = glow
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.m)
                    .fill(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.border, lineWidth: 1))
            )
            .shadow(color: glow ?? Theme.shadow.opacity(0.4), radius: glow == nil ? 6 : 12, x: 0, y: 4)
    }
}

// MARK: - Chip

struct Chip: View {
    let title: String
    var systemImage: String? = nil
    let selected: Bool
    var accent: Color = Theme.primary
    let action: () -> Void

    var body: some View {
        Button(action: { Haptic.select(); action() }) {
            HStack(spacing: 6) {
                if let s = systemImage { Image(systemName: s).font(.system(size: 12, weight: .semibold)) }
                Text(title).font(Theme.caption(13))
            }
            .foregroundColor(selected ? Theme.onPrimary : Theme.textSecond)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(selected ? accent : Theme.card)
                    .overlay(Capsule().stroke(selected ? accent : Theme.border, lineWidth: 1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Badges & tags

struct StatusBadge: View {
    let text: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let icon = icon { Image(systemName: icon).font(.system(size: 10, weight: .bold)) }
            Text(text.uppercased()).font(Theme.caption(10)).tracking(0.8)
        }
        .foregroundColor(color)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.15)))
        .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
    }
}

@MainActor
final class Deck: ObservableObject {
    
    @Published var showOfflineView = false
    
    @Published var navigateToMain = false {
        didSet {
            if navigateToMain {
                deadlineTask?.cancel()
                uiLocked = true
            }
        }
    }
    
    private var deadlineTask: Task<Void, Never>?
    private var uiLocked = false
    @Published var showPermissionPrompt = false

    private let rig: RebarRig
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.rig = Foreman.shared.assign(RebarRig.self)
        wireVerdicts()
    }

    private func settle(_ verdict: Verdict) {
        guard !uiLocked else { return }

        switch verdict {
        case .slack:
            break
        case .cinch:
            showPermissionPrompt = true
        case .span:
            navigateToWeb = true
        case .snapped:
            navigateToMain = true
        }
    }

    private func wireVerdicts() {
        rig.verdictStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] verdict in
                self?.settle(verdict)
            }
            .store(in: &cancellables)
    }

    func ignite() {
        rig.ensureStrung()
        armDeadline()
    }

    func ingestBars(_ data: [String: Any]) {
        Task {
            rig.takeBars(data)
            await rig.calc()
        }
    }

    func ingestLaps(_ data: [String: Any]) {
        rig.takeLaps(data)
    }

    @Published var navigateToWeb = false {
        didSet {
            if navigateToWeb {
                deadlineTask?.cancel()
                uiLocked = true
            }
        }
    }

    func acceptConsent() {
        rig.acceptCinch {
            self.showPermissionPrompt = false
        }
    }
    
    func skipConsent() {
        showPermissionPrompt = false
        rig.skipCinch()
    }

    func networkConnectivityChanged(_ connected: Bool) {
        if !connected {
            showOfflineView = true
        }
    }


    private func armDeadline() {
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard let self = self else { return }
            if self.rig.reportSnap() {
                self.settle(.snapped)
            }
        }
    }
    
    deinit {
        deadlineTask?.cancel()
    }
    
}


struct PillTag: View {
    let text: String
    var color: Color = Theme.line
    var body: some View {
        Text(text)
            .font(Theme.numeric(11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var systemImage: String? = nil
    var accent: Color = Theme.line

    var body: some View {
        HStack(spacing: 8) {
            if let s = systemImage {
                Image(systemName: s).font(.system(size: 13, weight: .bold)).foregroundColor(accent)
            }
            Text(title.uppercased())
                .font(Theme.caption(12)).tracking(1.2)
                .foregroundColor(Theme.textSecond)
            Spacer()
        }
    }
}

// MARK: - Info row (label + value)

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = Theme.mono
    var mono: Bool = true

    var body: some View {
        HStack {
            Text(label).font(Theme.body(14)).foregroundColor(Theme.textSecond)
            Spacer()
            Text(value)
                .font(mono ? Theme.numeric(14) : Theme.body(14))
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let value: String
    let label: String
    var accent: Color = Theme.primary
    var systemImage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let s = systemImage {
                Image(systemName: s).font(.system(size: 14, weight: .bold)).foregroundColor(accent)
            }
            Text(value).font(Theme.numeric(20, weight: .heavy)).foregroundColor(Theme.mono)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label.uppercased()).font(Theme.caption(10)).tracking(0.6).foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.s)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.s)
                .fill(Theme.bgSoft)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(accent.opacity(0.25), lineWidth: 1))
        )
    }
}

// MARK: - Ratio gauge (min reinforcement)

struct RatioGauge: View {
    let ratio: Double      // %
    let minRatio: Double   // %
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            // scale: show up to max(2*min, ratio*1.3)
            let scaleMax = max(minRatio * 2.2, ratio * 1.25, 0.2)
            let ratioX = CGFloat(min(1, ratio / scaleMax)) * w
            let minX = CGFloat(min(1, minRatio / scaleMax)) * w
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.bgDeep)
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.7), color],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, ratioX))
                    .shadow(color: color.opacity(0.5), radius: 4)
                // minimum marker
                Rectangle()
                    .fill(Theme.attention)
                    .frame(width: 2)
                    .offset(x: minX)
            }
        }
        .frame(height: 12)
    }
}

// MARK: - Inputs

struct ThemedTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        TextField(placeholder, text: $text)
            .font(Theme.body(15))
            .foregroundColor(Theme.text)
            .keyboardType(keyboard)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.bgDeep))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.border, lineWidth: 1))
    }
}

/// Numeric input bound to a Double, with a label and unit suffix.
struct NumberField: View {
    let title: String
    var unit: String = ""
    @Binding var value: Double
    var integer: Bool = false
    var minValue: Double = 0
    var maxValue: Double = 1_000_000

    @State private var text: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(Theme.caption(11)).tracking(0.6).foregroundColor(Theme.textMuted)
            HStack(spacing: 8) {
                TextField("", text: $text)
                    .font(Theme.numeric(16))
                    .foregroundColor(Theme.mono)
                    .keyboardType(integer ? .numberPad : .decimalPad)
                    .onChange(of: text) { newValue in commit(newValue) }
                if !unit.isEmpty {
                    Text(unit).font(Theme.caption(13)).foregroundColor(Theme.textMuted)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.bgDeep))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.border, lineWidth: 1))
        }
        .onAppear { text = formatted(value) }
    }

    private func formatted(_ v: Double) -> String {
        if integer { return String(Int(v.rounded())) }
        if v == v.rounded() { return String(Int(v)) }
        return String(format: "%g", v)
    }

    private func commit(_ raw: String) {
        let cleaned = raw.replacingOccurrences(of: ",", with: ".")
        if let parsed = Double(cleaned) {
            value = min(maxValue, max(minValue, parsed))
        } else if raw.isEmpty {
            value = minValue
        }
    }
}

/// Stepper with a centred value and minus/plus controls.
struct LabeledStepper: View {
    let title: String
    @Binding var value: Double
    var step: Double = 1
    var minValue: Double = 0
    var maxValue: Double = 100
    var unit: String = ""
    var integer: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(Theme.caption(11)).tracking(0.6).foregroundColor(Theme.textMuted)
            HStack(spacing: 12) {
                stepButton("minus") { value = max(minValue, value - step) }
                Spacer()
                Text(integer ? String(Int(value)) + (unit.isEmpty ? "" : " " + unit)
                              : Fmt.num(value) + (unit.isEmpty ? "" : " " + unit))
                    .font(Theme.numeric(17, weight: .bold)).foregroundColor(Theme.mono)
                Spacer()
                stepButton("plus") { value = min(maxValue, value + step) }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.bgDeep))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.border, lineWidth: 1))
        }
    }

    private func stepButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: { Haptic.select(); action() }) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.primary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.primary.opacity(0.15)))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Empty state

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Theme.line.opacity(0.6))
            Text(title).font(Theme.heading(17)).foregroundColor(Theme.text)
            Text(message).font(Theme.body(14)).foregroundColor(Theme.textSecond)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40).padding(.horizontal, 24)
    }
}

// MARK: - Disclaimer sheet

struct DisclaimerSheet: View {
    let onAccept: () -> Void

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: Theme.Space.l) {
                Spacer()
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundColor(Theme.attention)
                Text("Indicative figures only")
                    .font(Theme.title(24)).foregroundColor(Theme.text)
                    .multilineTextAlignment(.center)
                Text("Rebar Calc gives approximate quantities for planning and ordering. Reinforcement of load-bearing or critical structures must follow a structural engineer's design and the project drawings.")
                    .font(Theme.body(15)).foregroundColor(Theme.textSecond)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Space.l)
                Spacer()
                PrimaryButton(title: "I understand", systemImage: "checkmark") { onAccept() }
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.bottom, Theme.Space.xl)
            }
        }
    }
}

// MARK: - Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
