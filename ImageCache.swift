//
//  ImageCache.swift
//  CalorieAI
//
//  Disk cache for generated food photos, keyed by `FoodEntry.imageSignature`
//  (see `FoodEntry.signature(for:)`). Repeated foods ("banana", "coffee")
//  reuse the same file instead of paying for a new generation every time.
//

import Foundation

enum ImageCache {
    private static let directoryName = "GeneratedImageCache"

    private static var directoryURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = base.appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static func url(for signature: String) -> URL {
        directoryURL.appendingPathComponent("\(signature).jpg")
    }

    static func existingPath(for signature: String) -> String? {
        let fileURL = url(for: signature)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL.path : nil
    }

    @discardableResult
    static func store(_ data: Data, for signature: String) throws -> String {
        let fileURL = url(for: signature)
        try data.write(to: fileURL, options: .atomic)
        return fileURL.path
    }
}
