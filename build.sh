#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

swiftc -O -framework AppKit -framework CoreGraphics -framework ImageIO main.swift -o PDFToPNG

mkdir -p PDFToPNG.app/Contents/MacOS PDFToPNG.app/Contents/Resources
cp PDFToPNG PDFToPNG.app/Contents/MacOS/PDFToPNG
cp Info.plist PDFToPNG.app/Contents/Info.plist

if [ -f icon.icns ]; then
  cp icon.icns PDFToPNG.app/Contents/Resources/Icon.icns
elif [ -f icon.png ]; then
  if command -v makeicns >/dev/null 2>&1; then
    makeicns -32 icon.png
    if [ -f icon.icns ]; then
      cp icon.icns PDFToPNG.app/Contents/Resources/Icon.icns
    else
      echo "Warning: icon.icns not generated"
    fi
  else
    echo "Warning: makeicns not installed; skipping icon generation"
  fi
else
  echo "Warning: no icon found; skipping icon setup"
fi

echo "Built PDFToPNG.app"

