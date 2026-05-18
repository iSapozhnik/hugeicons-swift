import Foundation

private final class HugeiconsBundleToken {}

enum HugeiconsResources {
    static let bundle: Bundle = {
        #if HUGEICONS_SWIFTPM
        return .module
        #else
        return Bundle(for: HugeiconsBundleToken.self)
        #endif
    }()
}
