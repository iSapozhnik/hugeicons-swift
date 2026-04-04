import Testing
@testable import Hugeicons

@Test func assetSwiftIdentifierRoundTripsKnownAsset() async throws {
    let asset = Hugeicons.textCheck

    #expect(Hugeicons.asset(swiftIdentifier: asset.swiftIdentifier) == asset)
}

@Test func assetSwiftIdentifierReturnsNilForUnknownIdentifier() async throws {
    #expect(Hugeicons.asset(swiftIdentifier: "__not_a_real_icon__") == nil)
}

@Test func assetSwiftIdentifierLookupCoversFullCatalog() async throws {
    let resolvedAssets = Hugeicons.all.compactMap { asset in
        Hugeicons.asset(swiftIdentifier: asset.swiftIdentifier)
    }

    #expect(resolvedAssets.count == Hugeicons.all.count)
}
