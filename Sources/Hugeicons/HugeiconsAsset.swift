import AppKit
import Foundation
import SwiftUI

public struct HugeiconsAsset: Sendable, Hashable {
    public let sourceName: String
    public let swiftIdentifier: String
    public let resourceName: String

    public func url(bundle: Bundle? = nil) -> URL? {
        let resolvedBundle = bundle ?? .module
        return resolvedBundle.url(forResource: resourceName, withExtension: "svg")
    }

    public func nsImage(bundle: Bundle? = nil) -> NSImage? {
        guard let url = url(bundle: bundle) else {
            return nil
        }
        let image = NSImage(contentsOf: url)
        image?.isTemplate = true
        return image
    }

    @MainActor
    public func image(bundle: Bundle? = nil) -> Image {
        guard let image = nsImage(bundle: bundle) else {
            let resolvedBundle = bundle ?? .module
            fatalError(
                "Missing Hugeicons asset '\(resourceName).svg' (source '\(sourceName)') in bundle: \(resolvedBundle.bundlePath)"
            )
        }

        return Image(nsImage: image)
    }
}
