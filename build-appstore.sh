#!/usr/bin/env bash
set -euo pipefail

# App Store Build Script for PDFToPNG
# Before running: 
# 1. Install Xcode Command Line Tools: xcode-select --install
# 2. Create App Store Connect app with Bundle ID: com.malipetek.pdftopng
# 3. Download provisioning profile from App Store Connect

cd "$(dirname "$0")"

# Configuration
BUNDLE_ID="com.malipetek.pdftopng"
APP_NAME="PDFToPNG"
VERSION="1.0"
BUILD_NUMBER="1"

# Clean previous builds
rm -rf "$APP_NAME.app"
rm -rf build

# Create build directory
mkdir -p build

# Compile the app
echo "Compiling..."
swiftc -O -framework AppKit -framework CoreGraphics -framework ImageIO main.swift -o build/$APP_NAME

# Create app bundle
echo "Creating app bundle..."
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"

# Copy files
cp build/$APP_NAME "$APP_NAME.app/Contents/MacOS/$APP_NAME"
cp Info.plist "$APP_NAME.app/Contents/Info.plist"
cp icon.icns "$APP_NAME.app/Contents/Resources/Icon.icns" 2>/dev/null || echo "Warning: icon.icns not found"

# Set executable permissions
chmod +x "$APP_NAME.app/Contents/MacOS/$APP_NAME"

echo "App bundle created: $APP_NAME.app"
echo ""
echo "Next steps for App Store submission:"
echo "1. Open Xcode"
echo "2. Create a new project: App > macOS > App"
echo "3. Use Bundle ID: $BUNDLE_ID"
echo "4. Copy your $APP_NAME.app into the Xcode project"
echo "5. Set up code signing in Xcode Build Settings"
echo "6. Archive the app (Product > Archive)"
echo "7. Upload to App Store Connect from the Organizer window"
echo ""
echo "Or use Xcode command line tools:"
echo "xcodebuild -exportArchive -archivePath $APP_NAME.xcarchive -exportPath . -exportOptionsPlist ExportOptions.plist"
