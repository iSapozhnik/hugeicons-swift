import Foundation
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

public struct HugeiconsAsset: Sendable, Hashable {
    public let sourceName: String
    public let swiftIdentifier: String
    public let resourceName: String

    #if canImport(AppKit)
    public func nsImage(bundle: Bundle? = nil) -> NSImage? {
        let resolvedBundle = bundle ?? .module
        let image = resolvedBundle.image(forResource: NSImage.Name(resourceName))
        image?.isTemplate = true
        return image
    }
    #endif

    #if canImport(UIKit)
    public func uiImage(
        bundle: Bundle? = nil,
        compatibleWith traitCollection: UITraitCollection? = nil
    ) -> UIImage? {
        let resolvedBundle = bundle ?? .module
        return UIImage(
            named: resourceName,
            in: resolvedBundle,
            compatibleWith: traitCollection
        )?
        .withRenderingMode(.alwaysTemplate)
    }
    #endif

    @MainActor
    public func image(bundle: Bundle? = nil) -> Image {
        let resolvedBundle = bundle ?? .module
        return Image(resourceName, bundle: resolvedBundle)
    }
}
