//
//  AppDelegate.swift
//  PDF Extractor
//
//  Created by Muhammet Ali Petek on 3.01.2026.
//

import AppKit
import CoreGraphics
import ImageIO

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        run()
    }

    func run() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select PDF"
        openPanel.message = "Exports each page of the selected PDF to PNG at 300 DPI into a sibling folder named '<PDF name> pages'."
        openPanel.allowedContentTypes = [.pdf]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        if openPanel.runModal() != .OK { NSApp.terminate(nil); return }
        guard let pdfURL = openPanel.url else { NSApp.terminate(nil); return }
        process(pdfURL: pdfURL)
        NSApp.terminate(nil)
    }

    func process(pdfURL: URL) {
        let pdfName = pdfURL.deletingPathExtension().lastPathComponent
        let parentDir = pdfURL.deletingLastPathComponent()
        let outputDir = parentDir.appendingPathComponent("\(pdfName) pages")
        
        do {
            try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            convert(pdfURL: pdfURL, outDir: outputDir)
            
            let alert = NSAlert()
            alert.messageText = "Success!"
            alert.informativeText = "Exported \(getPageCount(pdfURL: pdfURL)) pages to \(outputDir.path)"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    func getPageCount(pdfURL: URL) -> Int {
        guard let doc = CGPDFDocument(pdfURL as CFURL) else { return 0 }
        return doc.numberOfPages
    }

    func convert(pdfURL: URL, outDir: URL) {
        guard let doc = CGPDFDocument(pdfURL as CFURL) else { return }
        let pageCount = doc.numberOfPages
        let dpi: CGFloat = 300.0
        let scale = dpi / 72.0
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        for i in 1...pageCount {
            guard let page = doc.page(at: i) else { continue }
            var box = page.getBoxRect(.mediaBox)
            if box.width == 0 || box.height == 0 {
                box = CGRect(x: 0, y: 0, width: 612, height: 792)
            }
            let width = Int(box.width * scale)
            let height = Int(box.height * scale)
            guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
            ctx.interpolationQuality = .high
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
            ctx.scaleBy(x: scale, y: scale)
            let pdfRect = CGRect(x: 0, y: 0, width: box.width, height: box.height)
            let t = page.getDrawingTransform(.mediaBox, rect: pdfRect, rotate: 0, preserveAspectRatio: true)
            ctx.concatenate(t)
            ctx.drawPDFPage(page)
            guard let image = ctx.makeImage() else { continue }
            let rep = NSBitmapImageRep(cgImage: image)
            guard let data = rep.representation(using: .png, properties: [:]) else { continue }
            let name = String(format: "page_%03d.png", i)
            let fileURL = outDir.appendingPathComponent(name)
            try? data.write(to: fileURL)
        }
    }
}
