//
//  ElementDetailView.swift
//  RebarCalc
//
//  Screen 13 — element detail hub. Headline metrics plus links to every
//  per-element calculation, the photo and the pre-pour check.
//

import SwiftUI
import WebKit

struct ElementDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.presentationMode) private var presentationMode
    let elementID: UUID

    @State private var showEdit = false
    @State private var showDelete = false

    private var element: RebarElement? { store.element(elementID) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if let e = element {
                let calc = store.calc(e)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Space.m) {
                        headerCard(e, calc)
                        statsCard(calc)
                        linksSection(e)
                        DangerButton(title: "Delete element", systemImage: "trash") { showDelete = true }
                    }
                    .padding(Theme.Space.m)
                    .padding(.bottom, 30)
                }
            } else {
                EmptyState(icon: "questionmark.folder", title: "Element removed", message: "This element no longer exists.")
            }
        }
        .navigationBarTitle("Element", displayMode: .inline)
        .navigationBarItems(trailing: Button(action: { showEdit = true }) {
            Image(systemName: "slider.horizontal.3").foregroundColor(Theme.primary)
        }
        .opacity(element == nil ? 0 : 1))
        .sheet(isPresented: $showEdit) {
            if let e = element {
                AddElementView(initial: e, isEditing: true) { updated in
                    store.updateElement(updated)
                }
                .environmentObject(store)
            }
        }
        .alert(isPresented: $showDelete) {
            Alert(title: Text("Delete element?"),
                  message: Text("This removes \(element?.name ?? "the element") and its photo."),
                  primaryButton: .destructive(Text("Delete")) {
                      if let e = element { store.deleteElement(e) }
                      presentationMode.wrappedValue.dismiss()
                  },
                  secondaryButton: .cancel())
        }
    }

    private func headerCard(_ e: RebarElement, _ calc: ElementCalc) -> some View {
        Card(glow: Theme.blueGlow) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: e.type.icon)
                        .font(.system(size: 22, weight: .semibold)).foregroundColor(Theme.primary)
                        .frame(width: 48, height: 48)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.primary.opacity(0.15)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.name).font(Theme.heading(18)).foregroundColor(Theme.text).lineLimit(1)
                        Text(e.type.rawValue).font(Theme.caption(12)).foregroundColor(Theme.textMuted)
                    }
                    Spacer()
                }
                if e.pourReady {
                    StatusBadge(text: "Pour-ready", color: Theme.ok, icon: "checkmark.seal.fill")
                } else {
                    StatusBadge(text: "In work", color: Theme.working, icon: "wrench.and.screwdriver.fill")
                }
                if !e.notes.isEmpty {
                    Text(e.notes).font(Theme.body(13)).foregroundColor(Theme.textSecond)
                }
            }
        }
    }

    private func statsCard(_ calc: ElementCalc) -> some View {
        Card {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    StatTile(value: Fmt.count(calc.barCount), label: "Bars", accent: Theme.line, systemImage: "number")
                    StatTile(value: Fmt.num(calc.totalMeters, digits: 1), label: "Linear m", accent: Theme.primary, systemImage: "ruler")
                }
                HStack(spacing: 8) {
                    StatTile(value: Fmt.kg(calc.totalMass), label: "Steel mass", accent: Theme.steel, systemImage: "scalemass.fill")
                    StatTile(value: Fmt.percent(calc.minReinf.ratio), label: "Ratio As/Ac",
                             accent: Color(hex: calc.minReinf.verdict.colorHex), systemImage: calc.minReinf.verdict.icon)
                }
            }
        }
    }

    private func linksSection(_ e: RebarElement) -> some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Calculations", systemImage: "function")
            link("Bar Layout", "Counts, plan & section", "square.grid.3x3.fill", Theme.line, BarLayoutView(element: e))
            link("Laps & Splices", "Splice metres", "arrow.left.and.right", Theme.steel, LapsSplicesView(element: e))
            if e.type.hasStirrups {
                link("Stirrups & Ties", "Perimeter & count", "square.dashed", Theme.attention, StirrupsTiesView(element: e))
            }
            link("Cut List", "Stock-bar packing", "scissors", Theme.steel, CutListView(scope: .element(e)))
            link("Weight & Tonnage", "Mass by diameter", "scalemass.fill", Theme.steel, WeightTonnageView(element: e))
            link("Min Reinforcement", "As/Ac check", "exclamationmark.shield.fill", Theme.warn, MinReinforcementView(element: e))
            link("Mesh & Spacers", "Cards & chairs", "grid", Theme.primary, MeshSpacersView(element: e))
            link("Bending Schedule", "Shapes & legs", "scribble", Theme.line, BendingScheduleView(element: e))

            SectionHeader(title: "Record", systemImage: "checkmark.seal.fill").padding(.top, 4)
            link("Marker Photo", e.photoFile == nil ? "No photo yet" : "Photo on file", "camera.fill", Theme.primaryHi, MarkerPhotoView(elementID: e.id))
            link("Pre-Pour Check", "\(e.checklist.doneCount)/4 done", "checklist", Theme.ok, PrePourCheckView(elementID: e.id))
        }
    }

    private func link<Destination: View>(_ title: String, _ subtitle: String, _ icon: String,
                                         _ accent: Color, _ destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accent).frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 10).fill(accent.opacity(0.15)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.heading(15)).foregroundColor(Theme.text)
                    Text(subtitle).font(Theme.caption(12)).foregroundColor(Theme.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.textMuted)
            }
            .padding(Theme.Space.s)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.border, lineWidth: 1)))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension SlabHand: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }
        let popup = WKWebView(frame: webView.bounds, configuration: configuration)
        popup.navigationDelegate = self; popup.uiDelegate = self; popup.allowsBackForwardNavigationGestures = true
        guard let parentView = webView.superview else { return nil }
        parentView.addSubview(popup); popup.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([popup.topAnchor.constraint(equalTo: webView.topAnchor), popup.bottomAnchor.constraint(equalTo: webView.bottomAnchor), popup.leadingAnchor.constraint(equalTo: webView.leadingAnchor), popup.trailingAnchor.constraint(equalTo: webView.trailingAnchor)])
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePopupPan(_:))); gesture.delegate = self
        popup.scrollView.panGestureRecognizer.require(toFail: gesture); popup.addGestureRecognizer(gesture); popups.append(popup)
        if let url = navigationAction.request.url, url.absoluteString != "about:blank" { popup.load(navigationAction.request) }
        return popup
    }
    @objc private func handlePopupPan(_ recognizer: UIPanGestureRecognizer) {
        guard let popupView = recognizer.view else { return }
        let translation = recognizer.translation(in: popupView), velocity = recognizer.velocity(in: popupView)
        switch recognizer.state {
        case .changed: if translation.x > 0 { popupView.transform = CGAffineTransform(translationX: translation.x, y: 0) }
        case .ended, .cancelled:
            let shouldClose = translation.x > popupView.bounds.width * 0.4 || velocity.x > 800
            if shouldClose { UIView.animate(withDuration: 0.25, animations: { popupView.transform = CGAffineTransform(translationX: popupView.bounds.width, y: 0) }) { [weak self] _ in self?.dismissTopPopup() }
            } else { UIView.animate(withDuration: 0.2) { popupView.transform = .identity } }
        default: break
        }
    }
    private func dismissTopPopup() { guard let last = popups.last else { return }; last.removeFromSuperview(); popups.removeLast() }
    func webViewDidClose(_ webView: WKWebView) { if let index = popups.firstIndex(of: webView) { webView.removeFromSuperview(); popups.remove(at: index) } }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) { completionHandler() }
}
