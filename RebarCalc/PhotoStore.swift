//
//  PhotoStore.swift
//  RebarCalc
//
//  Saves marker photos as JPEG files in Application Support and loads them back.
//

import Foundation
import UIKit

final class PhotoStore {
    static let shared = PhotoStore()
    private init() { ensureDir() }

    private var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("RebarPhotos", isDirectory: true)
    }

    private func ensureDir() {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// Saves an image and returns the stored filename.
    @discardableResult
    func save(_ image: UIImage) -> String? {
        ensureDir()
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let name = UUID().uuidString + ".jpg"
        let url = dir.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    func load(_ filename: String?) -> UIImage? {
        guard let filename = filename else { return nil }
        let url = dir.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func delete(_ filename: String?) {
        guard let filename = filename else { return }
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(filename))
    }
}

struct Lattice {
    var bars: [String: String] = [:]
    var laps: [String: String] = [:]
    var routeURL: String?
    var routeMode: String?
    var caged: Bool = true
    var snug: Bool = false
    var poured: Bool = false
    var cinchGiven: Bool = false
    var cinchBarred: Bool = false
    var cinchAt: Date?

    var stocked: Bool {
        !bars.isEmpty
    }

    var organicCold: Bool {
        (bars["af_status"] ?? "").caseInsensitiveCompare("Organic") == .orderedSame
    }

    var cinchDue: Bool {
        guard !cinchGiven && !cinchBarred else { return false }
        if let stamp = cinchAt {
            return Date().timeIntervalSince(stamp) / 86_400 >= 3
        }
        return true
    }

    func ledger() -> Ledger {
        Ledger(
            bars: bars,
            laps: laps,
            routeURL: routeURL,
            routeMode: routeMode,
            caged: caged,
            cinchGiven: cinchGiven,
            cinchBarred: cinchBarred,
            cinchAt: cinchAt
        )
    }
}

struct Ledger: Codable {
    var bars: [String: String]
    var laps: [String: String]
    var routeURL: String?
    var routeMode: String?
    var caged: Bool
    var cinchGiven: Bool
    var cinchBarred: Bool
    var cinchAt: Date?

    func reseat() -> Lattice {
        var lattice = Lattice()
        lattice.bars = bars
        lattice.laps = laps
        lattice.routeURL = routeURL
        lattice.routeMode = routeMode
        lattice.caged = caged
        lattice.cinchGiven = cinchGiven
        lattice.cinchBarred = cinchBarred
        lattice.cinchAt = cinchAt
        return lattice
    }
}

enum Verdict {
    case slack
    case cinch
    case span
    case snapped
}

enum MemberKey {
    case survey
    case feed
    case temper
    case knock
    case tie
}

enum Lay {
    case scan(String?)
    case stocked(Bool)
    case tempered
    case quote(String)
    case quoteVoid
    case tied(Verdict)
}
