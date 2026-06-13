//
//  AddElementView.swift
//  RebarCalc
//
//  Screen 02 — add or edit a structural element. Geometry, diameters, spacing,
//  cover, lap and layers. Validates before saving.
//

import SwiftUI

struct AddElementView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode

    var isEditing: Bool = false
    let onSave: (RebarElement) -> Void

    @State private var e: RebarElement

    init(initial: RebarElement, isEditing: Bool = false, onSave: @escaping (RebarElement) -> Void) {
        self.isEditing = isEditing
        self.onSave = onSave
        _e = State(initialValue: initial)
    }

    private let diameters = BarSize.all

    private var valid: Bool {
        !e.name.trimmingCharacters(in: .whitespaces).isEmpty &&
        e.length > 0 && e.sectionH > 0 &&
        (e.type.isPlanar ? (e.width > 0 && e.mainSpacing > 0) : (e.mainCount > 0 && e.sectionB > 0)) &&
        e.transSpacing > 0
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Space.l) {
                        typeSection
                        geometrySection
                        mainBarSection
                        transverseSection
                        coverLapSection
                    }
                    .padding(Theme.Space.m)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitle(isEditing ? "Edit Element" : "Add Element", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                    .foregroundColor(Theme.textSecond),
                trailing: Button("Save") {
                    Haptic.success()
                    onSave(e)
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(valid ? Theme.primary : Theme.textMuted)
                .disabled(!valid)
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: Sections

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Element type", systemImage: "square.grid.2x2.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ElementType.allCases) { t in
                        Chip(title: t.short, systemImage: t.icon, selected: e.type == t) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                applyType(t)
                            }
                        }
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name").font(Theme.caption(11)).tracking(0.6).foregroundColor(Theme.textMuted)
                    ThemedTextField(placeholder: "e.g. Beam B2", text: $e.name)
                }
            }
        }
    }

    private var geometrySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Geometry", systemImage: "ruler.fill")
            Card {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        NumberField(title: e.type.isPlanar ? "Length" : "Length / span / height",
                                    unit: "m", value: $e.length, minValue: 0)
                        if e.type.isPlanar {
                            NumberField(title: "Width", unit: "m", value: $e.width, minValue: 0)
                        }
                    }
                    HStack(spacing: 12) {
                        if !e.type.isPlanar {
                            NumberField(title: "Section width b", unit: "mm", value: $e.sectionB, integer: true, minValue: 0)
                        }
                        NumberField(title: e.type.isPlanar ? "Thickness" : "Section height h",
                                    unit: "mm", value: $e.sectionH, integer: true, minValue: 0)
                    }
                }
            }
        }
    }

    private var mainBarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Main reinforcement", systemImage: "circle.circle.fill", accent: Theme.steel)
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    diameterPicker(title: "Main bar Ø", selection: $e.mainDia)
                    if e.type.isPlanar {
                        NumberField(title: "Main bar spacing", unit: "mm", value: $e.mainSpacing, integer: true, minValue: 1)
                        LabeledStepper(title: "Mesh layers (1 = single, 2 = top+bottom)",
                                       value: layersBinding, step: 1, minValue: 1, maxValue: 2)
                    } else {
                        LabeledStepper(title: "Number of longitudinal bars",
                                       value: mainCountBinding, step: 1, minValue: 1, maxValue: 40)
                    }
                    Toggle(isOn: $e.endHooks) {
                        Text("Add end hooks / bends").font(Theme.body(14)).foregroundColor(Theme.text)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: Theme.primary))
                }
            }
        }
    }

    private var transverseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: e.type.isPlanar ? "Distribution bars" : "Stirrups / ties",
                          systemImage: "square.dashed", accent: Theme.attention)
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    diameterPicker(title: e.type.isPlanar ? "Distribution Ø" : "Stirrup Ø", selection: $e.transDia)
                    NumberField(title: e.type.isPlanar ? "Distribution spacing" : "Stirrup spacing",
                                unit: "mm", value: $e.transSpacing, integer: true, minValue: 1)
                }
            }
        }
    }

    private var coverLapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Cover & laps", systemImage: "arrow.left.and.right")
            Card {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        NumberField(title: "Concrete cover", unit: "mm", value: $e.cover, integer: true, minValue: 0, maxValue: 200)
                        NumberField(title: "Lap length", unit: "× d", value: $e.lapDiameters, integer: true, minValue: 0, maxValue: 80)
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func diameterPicker(title: String, selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(Theme.caption(11)).tracking(0.6).foregroundColor(Theme.textMuted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(diameters, id: \.self) { d in
                        Chip(title: "Ø\(d)", selected: selection.wrappedValue == d, accent: Theme.steel) {
                            selection.wrappedValue = d
                        }
                    }
                }
            }
        }
    }

    private func applyType(_ t: ElementType) {
        let wasName = e.name
        let d = t.defaults
        e.type = t
        // refresh geometry defaults that don't translate across element kinds
        if e.length == 0 { e.length = d.length }
        e.width = t.isPlanar ? (e.width > 0 ? e.width : d.width) : 0
        if e.sectionB == 0 { e.sectionB = d.b }
        if e.sectionH == 0 { e.sectionH = d.h }
        if t.isPlanar {
            e.layers = max(1, e.layers)
        } else {
            e.layers = 1
            if e.mainCount == 0 { e.mainCount = d.mainCount }
        }
        e.name = wasName
    }

    private var layersBinding: Binding<Double> {
        Binding(get: { Double(e.layers) }, set: { e.layers = Int($0) })
    }
    private var mainCountBinding: Binding<Double> {
        Binding(get: { Double(e.mainCount) }, set: { e.mainCount = Int($0) })
    }
}
