public enum Hugeicons {
    static let assetsBySwiftIdentifierStorage: [String: HugeiconsAsset] =
        Dictionary(uniqueKeysWithValues: HugeiconsCatalog.all.map { ($0.swiftIdentifier, $0) })

    public static var all: [HugeiconsAsset] {
        HugeiconsCatalog.all
    }

    public static func asset(swiftIdentifier: String) -> HugeiconsAsset? {
        assetsBySwiftIdentifierStorage[swiftIdentifier]
    }
}
