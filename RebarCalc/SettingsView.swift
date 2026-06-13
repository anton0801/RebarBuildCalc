//
//  SettingsView.swift
//  RebarCalc
//
//  Screen 18 — settings. Appearance (live), currency, cut/lap defaults, cost
//  rates, the editable bar-weight table, and data tools. Every control persists.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage("appearance") private var appearanceRaw = AppAppearance.dark.rawValue
    @AppStorage("currencySymbol") private var currency = "$"

    @State private var shareItem: ShareItem?
    @State private var showWipe = false
    @State private var showSample = false

    private let currencies = ["$", "€", "£", "₽", "₴", "zł"]

    var body: some View {
        NavigationView {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Space.l) {
                        appearanceSection
                        currencySection
                        cutLapSection
                        costSection
                        weightTableSection
                        dataSection
                        aboutSection
                    }
                    .padding(Theme.Space.m)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitle("Settings", displayMode: .inline)
            .sheet(item: $shareItem) { item in ShareSheet(items: [item.url]) }
            .alert(isPresented: $showWipe) {
                Alert(title: Text("Wipe all data?"),
                      message: Text("Deletes every element, reminder, photo and history entry. This cannot be undone."),
                      primaryButton: .destructive(Text("Wipe")) { store.wipeAll() },
                      secondaryButton: .cancel())
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Appearance", systemImage: "paintbrush.fill")
            Card {
                HStack(spacing: 8) {
                    ForEach(AppAppearance.allCases) { mode in
                        Chip(title: mode.label, systemImage: mode.icon,
                             selected: appearanceRaw == mode.rawValue) {
                            withAnimation { appearanceRaw = mode.rawValue }
                        }
                    }
                }
            }
        }
    }

    // MARK: Currency

    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Currency & units", systemImage: "dollarsign.circle.fill")
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(currencies, id: \.self) { c in
                                Chip(title: c, selected: currency == c, accent: Theme.primary) { currency = c }
                            }
                        }
                    }
                    Text("Lengths in metres / mm, mass in kg & tonnes.")
                        .font(Theme.caption(12)).foregroundColor(Theme.textMuted)
                }
            }
        }
    }

    // MARK: Cut & lap

    private var cutLapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Cut & lap defaults", systemImage: "scissors")
            Card {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        NumberField(title: "Stock bar length", unit: "m", value: dbl(\.stockLength), minValue: 1, maxValue: 24)
                        NumberField(title: "Default lap", unit: "× d", value: dbl(\.defaultLapDia), integer: true, minValue: 10, maxValue: 80)
                    }
                    HStack(spacing: 12) {
                        NumberField(title: "Default cover", unit: "mm", value: dbl(\.defaultCover), integer: true, minValue: 10, maxValue: 100)
                        NumberField(title: "Hook factor", unit: "× d", value: dbl(\.hookFactor), integer: true, minValue: 4, maxValue: 20)
                    }
                }
            }
        }
    }

    // MARK: Costs

    private var costSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Cost rates (\(currency))", systemImage: "tag.fill")
            Card {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        NumberField(title: "Steel price / kg", unit: currency, value: dbl(\.steelPrice), minValue: 0, maxValue: 100)
                        NumberField(title: "Wire / tonne", unit: "kg", value: dbl(\.tieWirePerTonne), minValue: 0, maxValue: 100)
                    }
                    HStack(spacing: 12) {
                        NumberField(title: "Wire price / kg", unit: currency, value: dbl(\.tieWirePrice), minValue: 0, maxValue: 100)
                        NumberField(title: "Labor / tonne", unit: currency, value: dbl(\.laborPerTonne), minValue: 0, maxValue: 5000)
                    }
                    HStack(spacing: 12) {
                        NumberField(title: "Spacer grid", unit: "m", value: dbl(\.spacerSpacing), minValue: 0.2, maxValue: 3)
                        NumberField(title: "Spacer price", unit: currency, value: dbl(\.spacerPrice), minValue: 0, maxValue: 50)
                    }
                }
            }
        }
    }

    // MARK: Weight table

    private var weightTableSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Bar weight table (kg/m)", systemImage: "scalemass.fill")
            Card {
                VStack(spacing: 8) {
                    ForEach(BarSize.all, id: \.self) { dia in
                        HStack {
                            PillTag(text: "Ø\(dia)", color: Theme.steel)
                            Text("default \(Fmt.num(BarSize.kgPerMeter(dia), digits: 3))")
                                .font(Theme.caption(11)).foregroundColor(Theme.textMuted)
                            Spacer()
                            NumberField(title: "", unit: "kg/m", value: weightBinding(dia), minValue: 0.05, maxValue: 20)
                                .frame(width: 150)
                        }
                        if dia != BarSize.all.last { Divider().background(Theme.border.opacity(0.5)) }
                    }
                    Button(action: { resetWeights() }) {
                        Text("Reset to d²/162 table").font(Theme.caption(13)).foregroundColor(Theme.primary)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: Data

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Data", systemImage: "externaldrive.fill")
            VStack(spacing: 10) {
                SecondaryButton(title: "Export backup (JSON)", systemImage: "square.and.arrow.up") {
                    if let url = PersistenceManager.shared.exportURL(store.data) {
                        shareItem = ShareItem(url: url)
                    }
                }
                SecondaryButton(title: "Load sample object", systemImage: "shippingbox.fill") {
                    showSample = true
                }
                .alert(isPresented: $showSample) {
                    Alert(title: Text("Load sample data?"),
                          message: Text("Replaces current data with a sample object."),
                          primaryButton: .default(Text("Load")) { store.loadSample() },
                          secondaryButton: .cancel())
                }
                DangerButton(title: "Wipe all data", systemImage: "trash") { showWipe = true }
            }
        }
    }

    private var aboutSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "exclamationmark.shield.fill").foregroundColor(Theme.attention)
                    Text("Rebar Calc").font(Theme.heading(15)).foregroundColor(Theme.text)
                    Spacer()
                    Text("v1.0").font(Theme.caption(12)).foregroundColor(Theme.textMuted)
                }
                Text("Indicative quantities for planning and ordering. Reinforcement of load-bearing or critical structures must follow a structural engineer's design.")
                    .font(Theme.caption(12)).foregroundColor(Theme.textSecond)
            }
        }
    }

    // MARK: Bindings

    private func dbl(_ kp: WritableKeyPath<ProjectSettings, Double>) -> Binding<Double> {
        Binding(get: { store.settings[keyPath: kp] },
                set: { var s = store.settings; s[keyPath: kp] = $0; store.updateSettings(s) })
    }

    private func weightBinding(_ dia: Int) -> Binding<Double> {
        Binding(get: { store.settings.kgPerMeter(dia) },
                set: { var s = store.settings; s.barWeightOverrides[String(dia)] = $0; store.updateSettings(s) })
    }

    private func resetWeights() {
        var s = store.settings
        s.barWeightOverrides = [:]
        store.updateSettings(s)
        Haptic.light()
    }
}
