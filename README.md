# PDFToPNG (macOS)

Convert each page of a PDF into PNG images and extract embedded images — packaged as a simple macOS app you can click or drag PDFs onto.

## Features

- Page-to-PNG conversion at 300 DPI
- Auto-creates sibling output folder: `<PDF name> pages`
- Extracts embedded images into `<PDF name> pages/images`
- Opens the output folder after processing
- Accepts drag-and-drop onto the app icon and "Open With" in Finder
- Optional app icon via `makeicns`

## Requirements

- macOS 10.13+
- Xcode Command Line Tools (`xcode-select --install`)
- Optional: Homebrew for `makeicns`

## Usage

- Click the app, select a PDF. The app shows a message: it will export each page to PNG at 300 DPI into `<PDF name> pages` next to the PDF and open the folder.
- Drag a PDF onto the app icon (Finder/Dock/Open With) to process directly.
- Finder toolbar: hold `Command` and drag `PDFToPNG.app` into the toolbar, then drop PDFs on it.

## Build Locally

```bash
# Build the binary
swiftc -O -framework AppKit -framework CoreGraphics -framework ImageIO main.swift -o PDFToPNG

# Create the app bundle
mkdir -p PDFToPNG.app/Contents/{MacOS,Resources}
cp PDFToPNG PDFToPNG.app/Contents/MacOS/PDFToPNG
cp Info.plist PDFToPNG.app/Contents/Info.plist

# Optional: set the app icon
brew install makeicns
ln -sf icon.png image.png
makeicns -32 image.png
cp image.icns PDFToPNG.app/Contents/Resources/Icon.icns
```

## Code Map

- Launch and selection message: `main.swift:10–21`
- Conversion (render pages): `main.swift:24–54`
- Processing flow and folder creation: `main.swift:56–66`
- Image extraction (embedded XObjects): `main.swift:68–160`
- Drag/Open handling: `main.swift:162–167`
- Document type registration: `Info.plist` → `CFBundleDocumentTypes`

## Signed Distribution (Trusted by Apple)

1. Sign with a Developer ID certificate (hardened runtime + timestamp):
   ```bash
   codesign --force --deep --options runtime --timestamp \
     --sign "Developer ID Application: Your Name (TEAMID)" PDFToPNG.app
   codesign --verify --deep --strict --verbose=2 PDFToPNG.app
   ```
2. Zip and notarize, then staple:
   ```bash
   ditto -c -k --keepParent PDFToPNG.app PDFToPNG-macos.zip
   xcrun notarytool submit PDFToPNG-macos.zip --apple-id YOUR_APPLE_ID \
     --team-id TEAMID --password APP_SPECIFIC_PASSWORD --wait
   xcrun stapler staple PDFToPNG.app
   ```
3. Gatekeeper check:
   ```bash
   spctl --assess --type execute --verbose PDFToPNG.app
   ```

## GitHub Releases (Automated)

- The workflow in `.github/workflows/release.yml` builds, signs, notarizes, and attaches `PDFToPNG-macos.zip` to a GitHub Release.
- Trigger: push a tag like `v1.0.0`.
  ```bash
  git tag v1.0.0
  git push origin v1.0.0
  ```
- Required secrets:
  - `DEVELOPER_ID_P12_BASE64`, `DEVELOPER_ID_P12_PASSWORD`, `DEVELOPER_ID_IDENTITY`
  - `NOTARY_APPLE_ID`, `NOTARY_TEAM_ID`, `NOTARY_APP_PASSWORD`
- Optional manual trigger: add `workflow_dispatch` under `on:` to run from the Actions UI.

## Notes

- Bundle identifier: `Info.plist` → `CFBundleIdentifier` must be unique (e.g., `com.yourorg.pdftopng`).
- Update `CFBundleShortVersionString` and `CFBundleVersion` for every release.
- For Mac App Store distribution, create an Xcode project and enable App Sandbox with user-selected file permissions.

## License

Specify your preferred license here.
