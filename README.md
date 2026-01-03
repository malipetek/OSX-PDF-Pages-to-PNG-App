# PDF Extractor

A simple macOS application that converts PDF pages to high-quality PNG images.

## Features

- One-click PDF to PNG conversion
- High-quality 300 DPI output
- Automatic folder creation for exported pages
- Simple, intuitive interface
- Native macOS app built with Swift

## Requirements

- macOS 10.13 or later
- Apple Developer Account (for App Store distribution)

## Building

This project uses Xcode Cloud for automated builds. To build locally:

1. Open `PDF Extractor.xcodeproj` in Xcode
2. Select "PDF Extractor" scheme
3. Choose "My Mac" as destination
4. Product → Archive

## App Store Distribution

See `PDF Extractor/APPSTORE_README.md` for detailed App Store submission instructions.

## Project Structure

```
PDF Extractor/
├── PDF Extractor.xcodeproj/    # Xcode project file
├── PDF Extractor/              # Source code
│   ├── AppDelegate.swift      # Main application logic
│   ├── PDF_ExtractorApp.swift # App entry point
│   ├── Assets.xcassets/       # Icons and images
│   ├── Info.plist            # App configuration
│   └── PDF_Extractor.entitlements # App permissions
├── .ci/                       # Xcode Cloud workflows
├── ExportOptions.plist        # Export configuration
└── README.md                  # This file
```

## License

Copyright © 2025 Ali Petek. All rights reserved.
