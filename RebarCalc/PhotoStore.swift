//
//  PhotoStore.swift
//  RebarCalc
//
//  Saves marker photos as JPEG files in Application Support and loads them back.
//

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
