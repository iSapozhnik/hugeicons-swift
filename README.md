# Hugeicons Swift

<!-- BEGIN_LOGO -->
<img src="https://avatars.githubusercontent.com/u/130147052?v=4" width="128" align="right" />
<!-- END_LOGO -->

> [!NOTE]
> This is an unofficial Hugeicons Swift package and is not affiliated with or maintained by the Hugeicons team.
> This package contains only free Hugeicons assets and does not include premium/pro icons.

This Swift package wraps the free Hugeicons source package: `@hugeicons/core-free-icons`.

### Key Highlights
- **5,000+ Free Icons**: Stroke Rounded set for unlimited personal and commercial projects
- **Pixel Perfect Grid**: Built on a 24x24 grid for crisp rendering at any size
- **Customizable**: Easily adjust colors, sizes, and styles to match your design needs

![Hugeicons Icons](https://raw.githubusercontent.com/hugeicons/react/main/assets/icons.png)

## For Developers (Using Icons)

Use the generated namespace:

- `Hugeicons.arrowDownLeft01`
- `Hugeicons.repeatIcon` (keyword-safe)
- `Hugeicons.all`

### Installation (Developers)

Add the package with Swift Package Manager.

Xcode:

1. `File` -> `Add Package Dependencies...`
2. Enter this repository URL
3. Add product `Hugeicons` to your target

`Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/isapozhnik/hugeicons-swift.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "Hugeicons", package: "hugeicons-swift")
        ]
    )
]
```

Then import in app code:

```swift
import Hugeicons
```

### Usage

Basic icon rendering:

```swift
Hugeicons.addTeam.image()
```

Toolbar action:

```swift
struct EditorView: View {
    var body: some View {
        Text("Document")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: syncNow) {
                        Hugeicons.refresh.image()
                    }
                    .help("Sync now")
                }
            }
    }

    private func syncNow() {}
}
```

List/sidebar row icon:

```swift
List {
    HStack(spacing: 8) {
        Hugeicons.mail01.image()
        Text("Inbox")
    }

    HStack(spacing: 8) {
        Hugeicons.sent.image()
        Text("Sent")
    }
}
```

State-driven icon:

```swift
let icon = isMuted ? Hugeicons.volumeMute01 : Hugeicons.volumeHigh
icon.image()
    .foregroundStyle(isMuted ? .secondary : .primary)
```

Persist and restore by stable identifier:

```swift
let persistedID = Hugeicons.textCheck.swiftIdentifier
let restoredIcon = Hugeicons.asset(swiftIdentifier: persistedID)
```

AppKit menu item:

```swift
let item = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
item.image = Hugeicons.settings01.nsImage()
    ?? NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
```

Notes:

- `image()` is non-optional and fails fast if the icon resource is missing.
- `nsImage()` and `uiImage()` are optional and can be used for defensive flows.

## For Maintainers (Pipeline and Updates)

Important: the npm payload does not ship raw `.svg` files. It ships icon modules in `dist/esm/*Icon.js`, and the fetch script converts those modules into PDF-backed `.imageset` entries in `Hugeicons.xcassets`.

### Installation (Maintainers)

Clone and enter repository:

```bash
git clone https://github.com/<org>/hugeicons-swift.git
cd hugeicons-swift
```

Install required tooling (macOS/Homebrew):

```bash
brew install node swiftgen
npm ci
```

Verify tooling:

```bash
node --version
npm --version
swiftgen --version
swift --version
```

Build once:

```bash
swift build
```

### Dependencies

Required tools:

- Node.js + npm (used by `npm pack` and the JS converter)
- SwiftGen CLI (used to generate `Assets+Generated.swift`)
- npm dev dependencies from `package.json` (install with `npm ci`)

### Generated artifacts

- Asset catalog payload:
  - `Sources/Hugeicons/Resources/Hugeicons/Hugeicons.xcassets/*.imageset/*.pdf`
  - `Sources/Hugeicons/Resources/Hugeicons/Hugeicons.xcassets/conversion-report.json`
- Metadata artifact:
  - `Sources/Hugeicons/Resources/Hugeicons/name-map.json`
- Swift API artifacts:
  - `Sources/Hugeicons/Generated/Assets+Generated.swift` (SwiftGen output, machine-owned)
  - `Sources/Hugeicons/Generated/Hugeicons+Catalog.generated.swift` (wrapper catalog, machine-owned)

### Scripts

Run commands from repository root.

1. Fetch free Hugeicons asset catalog
- Script: `Scripts/icons/fetch_hugeicons_free.sh`
- Usage: `Scripts/icons/fetch_hugeicons_free.sh [--version-lock <path>] [--output-dir <path>]`

2. Verify generated asset catalog
- Script: `Scripts/icons/verify_hugeicons_xcassets.swift`
- Usage: `Scripts/icons/verify_hugeicons_xcassets.swift <xcassets-root-dir> [--report-path <path>] [--max-skipped <count>]`

3. Generate stable Swift name map
- Script: `Scripts/icons/generate_hugeicons_name_map.swift`
- Usage: `Scripts/icons/generate_hugeicons_name_map.swift <xcassets-root-dir> <name-map-output-path>`

4. Generate Swift wrappers
- Script: `Scripts/icons/generate_hugeicons_swift_api.sh`
- Runs:
  1. `swiftgen config lint --config swiftgen.yml`
  2. `swiftgen config run --config swiftgen.yml`
  3. `Scripts/icons/generate_hugeicons_wrapper.swift ...`

5. One-command refresh
- Script: `Scripts/icons/update_hugeicons_free.sh`
- Runs:
  1. fetch
  2. verify asset catalog
  3. regenerate name map + Swift wrapper API
  4. print added/removed/renamed summary

### Standard refresh flow

1. Set pinned version in `version.lock`.
2. Run `Scripts/icons/update_hugeicons_free.sh`.
