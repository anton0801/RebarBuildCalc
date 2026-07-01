//
//  ImagePicker.swift
//  RebarCalc
//
//  UIImagePickerController bridge for the Marker Photo screen (camera + library).
//

import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    let onPick: (UIImage) -> Void
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            picker.sourceType = sourceType
        } else {
            picker.sourceType = .photoLibrary
        }
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onPick(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

protocol Shelf {
    func pin(_ ledger: Ledger)
    func recall() -> Lattice
    func brandRoute(url: String, mode: String)
    func raisePrimedFlag()
}

final class SteelShelf: Shelf {

    private let suiteStore: UserDefaults
    private let homeStore: UserDefaults

    private var ledgerURL: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent(Bar.bayVault, isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder.appendingPathComponent(Bar.ledgerFile)
    }

    init() {
        self.suiteStore = UserDefaults(suiteName: Bar.suiteBay) ?? .standard
        self.homeStore = .standard
    }

    func pin(_ ledger: Ledger) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        if let raw = try? encoder.encode(ledger) {
            try? veil(raw).write(to: ledgerURL, options: .atomic)
        }

        suiteStore.set(ledger.cinchGiven, forKey: BarKey.cinchGiven)
        suiteStore.set(ledger.cinchBarred, forKey: BarKey.cinchBarred)
        homeStore.set(ledger.cinchGiven, forKey: BarKey.cinchGiven)
        homeStore.set(ledger.cinchBarred, forKey: BarKey.cinchBarred)
        if let stamp = ledger.cinchAt {
            suiteStore.set(stamp.timeIntervalSince1970, forKey: BarKey.cinchAt)
            homeStore.set(stamp.timeIntervalSince1970, forKey: BarKey.cinchAt)
        }
    }

    func recall() -> Lattice {
        if let blob = try? Data(contentsOf: ledgerURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            if let ledger = try? decoder.decode(Ledger.self, from: unveil(blob)) {
                return ledger.reseat()
            }
        }

        let given = suiteStore.bool(forKey: BarKey.cinchGiven) || homeStore.bool(forKey: BarKey.cinchGiven)
        let barred = suiteStore.bool(forKey: BarKey.cinchBarred) || homeStore.bool(forKey: BarKey.cinchBarred)
        let stampValue = suiteStore.double(forKey: BarKey.cinchAt)
        let stamp: Date? = stampValue > 0 ? Date(timeIntervalSince1970: stampValue) : nil

        var lattice = Lattice()
        lattice.routeURL = homeStore.string(forKey: BarKey.routeURL)
        lattice.routeMode = suiteStore.string(forKey: BarKey.routeMode)
        lattice.caged = !suiteStore.bool(forKey: BarKey.primed)
        lattice.cinchGiven = given
        lattice.cinchBarred = barred
        lattice.cinchAt = stamp
        return lattice
    }

    func brandRoute(url: String, mode: String) {
        homeStore.set(url, forKey: BarKey.routeURL)
        suiteStore.set(url, forKey: BarKey.routeURL)
        suiteStore.set(mode, forKey: BarKey.routeMode)
    }

    func raisePrimedFlag() {
        suiteStore.set(true, forKey: BarKey.primed)
        homeStore.set(true, forKey: BarKey.primed)
    }

    private func veil(_ data: Data) -> Data {
        let swapped = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "*")
            .replacingOccurrences(of: "/", with: "-")
        return Data(swapped.utf8)
    }

    private func unveil(_ data: Data) -> Data {
        let text = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "*", with: "+")
            .replacingOccurrences(of: "-", with: "/")
        return Data(base64Encoded: text) ?? Data()
    }
}
