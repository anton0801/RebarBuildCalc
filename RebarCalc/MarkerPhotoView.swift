//
//  MarkerPhotoView.swift
//  RebarCalc
//
//  Screen 12 — marker photo. Capture or import a photo of the tied cage with
//  caption tags (spacing, lap, cover) for the record before the pour.
//

import SwiftUI

struct MarkerPhotoView: View {
    @EnvironmentObject var store: AppStore
    let elementID: UUID

    @State private var showPicker = false
    @State private var pickerSource: UIImagePickerController.SourceType = .camera

    private var element: RebarElement? { store.element(elementID) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Space.m) {
                    if let e = element {
                        photoCard(e)
                        tagsCard(e)
                        buttons(e)
                    }
                }
                .padding(Theme.Space.m)
                .padding(.bottom, 30)
            }
        }
        .navigationBarTitle("Marker Photo", displayMode: .inline)
        .sheet(isPresented: $showPicker) {
            ImagePicker(sourceType: pickerSource) { image in
                if let name = PhotoStore.shared.save(image) {
                    store.setPhoto(name, for: elementID)
                    Haptic.success()
                }
            }
        }
    }

    private func photoCard(_ e: RebarElement) -> some View {
        Card {
            ZStack {
                if let image = PhotoStore.shared.load(e.photoFile) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 240)
                        .clipped()
                        .cornerRadius(Theme.Radius.s)
                        .overlay(
                            // caption tags overlaid bottom
                            VStack {
                                Spacer()
                                HStack {
                                    captionTag("Ø\(e.mainDia) @ \(Int(e.mainSpacing.rounded()))")
                                    captionTag("cover \(Int(e.cover))")
                                    captionTag("lap \(Int(e.lapDiameters))×d")
                                }
                                .padding(8)
                            }
                        )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 44, weight: .light))
                            .foregroundColor(Theme.line.opacity(0.6))
                        Text("No photo yet").font(Theme.heading(15)).foregroundColor(Theme.textSecond)
                        Text("Capture the tied cage to fix the spacing, laps and cover before the pour.")
                            .font(Theme.body(13)).foregroundColor(Theme.textMuted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(height: 240).frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func captionTag(_ text: String) -> some View {
        Text(text)
            .font(Theme.numeric(11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.6)))
            .overlay(Capsule().stroke(Theme.steel.opacity(0.8), lineWidth: 1))
    }

    private func tagsCard(_ e: RebarElement) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "Tagged values", systemImage: "tag.fill")
                InfoRow(label: "Main spacing", value: Fmt.mm(e.mainSpacing))
                InfoRow(label: "Cover", value: Fmt.mm(e.cover))
                InfoRow(label: "Lap", value: "\(Int(e.lapDiameters)) × Ø")
            }
        }
    }

    private func buttons(_ e: RebarElement) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                SecondaryButton(title: "Camera", systemImage: "camera.fill") {
                    pickerSource = .camera
                    showPicker = true
                }
                SecondaryButton(title: "Library", systemImage: "photo.fill") {
                    pickerSource = .photoLibrary
                    showPicker = true
                }
            }
            if e.photoFile != nil {
                DangerButton(title: "Remove photo", systemImage: "trash") {
                    store.setPhoto(nil, for: elementID)
                }
            }
        }
    }
}
