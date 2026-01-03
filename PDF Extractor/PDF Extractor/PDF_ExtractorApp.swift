//
//  PDF_ExtractorApp.swift
//  PDF Extractor
//
//  Created by Muhammet Ali Petek on 3.01.2026.
//

import AppKit

@main
struct PDF_ExtractorApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
