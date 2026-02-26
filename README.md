# Hugeicons Swift

<!-- BEGIN_LOGO -->
<img src="https://avatars.githubusercontent.com/u/130147052?v=4" width="128" align="right" />
<!-- END_LOGO -->

> [!NOTE]
> This is an unofficial Hugeicons Swift package and is not affiliated with or maintained by the Hugeicons team.
> This package contains only free Hugeicons assets and does not include premium/pro icons.

This Swift package wraps the free Hugeicons source package: `@hugeicons/core-free-icons`.

### Key Highlights
- **4,600+ Free Icons**: Stroke Rounded set for unlimited personal and commercial projects
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

AppKit menu item:

```swift
let item = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
item.image = Hugeicons.settings01.nsImage()
    ?? NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
```

Load icon file URL directly (for custom renderers/web views):

```swift
if let iconURL = Hugeicons.qrCode.url() {
    webView.loadFileURL(iconURL, allowingReadAccessTo: iconURL.deletingLastPathComponent())
}
```

Notes:

- `image()` is non-optional and fails fast if the icon resource is missing.
- `nsImage()` and `url()` are optional and can be used for defensive flows.

## For Maintainers (Pipeline and Updates)

Important: the npm payload does not ship raw `.svg` files. It ships icon modules in `dist/esm/*Icon.js`, and the fetch script converts those modules into `.svg` files.

### Installation (Maintainers)

Clone and enter repository:

```bash
git clone https://github.com/<org>/hugeicons-swift.git
cd hugeicons-swift
```

Install required tooling (macOS/Homebrew):

```bash
brew install node
brew install swiftgen
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
- SwiftGen CLI (used to generate `HugeiconsGenerated.swift`)

### Generated artifacts

- Raw payload:
  - `Sources/Hugeicons/Resources/Hugeicons/raw/*.svg`
- Verification artifacts:
  - `Sources/Hugeicons/Resources/Hugeicons/raw/conversion-report.json`
  - `Sources/Hugeicons/Resources/Hugeicons/manifest.json`
  - `Sources/Hugeicons/Resources/Hugeicons/name-map.json`
- Swift API artifacts:
  - `Sources/Hugeicons/Generated/HugeiconsGenerated.swift` (SwiftGen output, machine-owned)
  - `Sources/Hugeicons/Generated/Hugeicons+Catalog.generated.swift` (wrapper catalog, machine-owned)

### Scripts

Run commands from repository root.

1. Fetch free Hugeicons SVGs
- Script: `Scripts/icons/fetch_hugeicons_free.sh`
- Usage: `Scripts/icons/fetch_hugeicons_free.sh [--version-lock <path>] [--output-dir <path>]`

2. Verify SVG payload + manifest
- Script: `Scripts/icons/verify_hugeicons_free.swift`
- Usage: `Scripts/icons/verify_hugeicons_free.swift <svg-root-dir> <manifest-output-path>`

3. Generate stable Swift name map
- Script: `Scripts/icons/generate_hugeicons_name_map.swift`
- Usage: `Scripts/icons/generate_hugeicons_name_map.swift <svg-root-dir> <name-map-output-path>`

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
  2. verify
  3. regenerate name map + Swift wrapper API
  4. print added/removed/renamed summary

### Standard refresh flow

1. Set pinned version in `version.lock`.
2. Run `Scripts/icons/update_hugeicons_free.sh`.
