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
        openPanel.allowedFileTypes = ["pdf"]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        if openPanel.runModal() != .OK { NSApp.terminate(nil); return }
        guard let pdfURL = openPanel.url else { NSApp.terminate(nil); return }
        process(pdfURL: pdfURL)
        NSApp.terminate(nil)
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
            let url = outDir.appendingPathComponent(name)
            try? data.write(to: url)
        }
    }

    func process(pdfURL: URL) {
        let baseName = pdfURL.deletingPathExtension().lastPathComponent
        let parentDir = pdfURL.deletingLastPathComponent()
        let outDir = parentDir.appendingPathComponent("\(baseName) pages")
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        convert(pdfURL: pdfURL, outDir: outDir)
        let imagesDir = outDir.appendingPathComponent("images")
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        extractImages(pdfURL: pdfURL, imagesDir: imagesDir)
        NSWorkspace.shared.open(outDir)
    }

    func extractImages(pdfURL: URL, imagesDir: URL) {
        guard let doc = CGPDFDocument(pdfURL as CFURL) else { return }
        let pageCount = doc.numberOfPages
        for i in 1...pageCount {
            guard let page = doc.page(at: i) else { continue }
            guard let pageDict = page.dictionary else { continue }
            var resDict: CGPDFDictionaryRef?
            if !CGPDFDictionaryGetDictionary(pageDict, "Resources", &resDict) { continue }
            guard let resources = resDict else { continue }

            let table = CGPDFOperatorTableCreate()!
            typealias CCallback = @convention(c) (CGPDFScannerRef?, UnsafeMutableRawPointer?) -> Void
            class ScannerContext {
                let resources: CGPDFDictionaryRef
                let imagesDir: URL
                let pageIndex: Int
                var imageIndex: Int = 0
                init(resources: CGPDFDictionaryRef, imagesDir: URL, pageIndex: Int) {
                    self.resources = resources
                    self.imagesDir = imagesDir
                    self.pageIndex = pageIndex
                }
            }

            let callback: CCallback = { scanner, info in
                guard let scanner, let info else { return }
                let ctxPtr = info.assumingMemoryBound(to: ScannerContext.self)
                let ctx = ctxPtr.pointee
                var namePtr: UnsafePointer<Int8>? = nil
                if !CGPDFScannerPopName(scanner, &namePtr) { return }
                guard let namePtr else { return }
                let name = String(cString: namePtr)
                var xobjDictRef: CGPDFDictionaryRef?
                if !CGPDFDictionaryGetDictionary(ctx.resources, "XObject", &xobjDictRef) { return }
                guard let xobjDict = xobjDictRef else { return }
                var objRef: CGPDFObjectRef?
                if !CGPDFDictionaryGetObject(xobjDict, name, &objRef) { return }
                guard let obj = objRef else { return }
                var streamRef: CGPDFStreamRef?
                if !CGPDFObjectGetValue(obj, .stream, &streamRef) { return }
                guard let stream = streamRef else { return }
                guard let dict = CGPDFStreamGetDictionary(stream) else { return }
                var subtypePtr: UnsafePointer<Int8>? = nil
                if !CGPDFDictionaryGetName(dict, "Subtype", &subtypePtr) { return }
                guard let subtypePtr, String(cString: subtypePtr) == "Image" else { return }

                var df = CGPDFDataFormat.raw
                guard let cfData = CGPDFStreamCopyData(stream, &df) else { return }
                var image: CGImage?
                if let src = CGImageSourceCreateWithData(cfData, nil) {
                    image = CGImageSourceCreateImageAtIndex(src, 0, nil)
                }

                if image == nil {
                    var widthI: Int = 0
                    var heightI: Int = 0
                    var bpcI: Int = 8
                    _ = CGPDFDictionaryGetInteger(dict, "Width", &widthI)
                    _ = CGPDFDictionaryGetInteger(dict, "Height", &heightI)
                    _ = CGPDFDictionaryGetInteger(dict, "BitsPerComponent", &bpcI)
                    var csNamePtr: UnsafePointer<Int8>? = nil
                    _ = CGPDFDictionaryGetName(dict, "ColorSpace", &csNamePtr)
                    let comps = (csNamePtr != nil && String(cString: csNamePtr!) == "DeviceGray") ? 1 : 3
                    let width = widthI, height = heightI, bpc = bpcI
                    let bytesPerRow = width * comps * bpc / 8
                    if let provider = CGDataProvider(data: cfData) {
                        let space = (comps == 1 ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB())
                        let bmpInfo = CGBitmapInfo()
                        image = CGImage(width: width, height: height, bitsPerComponent: bpc, bitsPerPixel: comps * bpc, bytesPerRow: bytesPerRow, space: space, bitmapInfo: bmpInfo, provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
                    }
                }

                guard let finalImage = image else { return }
                var alphaMask: CGImage? = nil
                var smaskStreamRef: CGPDFStreamRef?
                if let dict = CGPDFStreamGetDictionary(stream), CGPDFDictionaryGetStream(dict, "SMask", &smaskStreamRef), let smaskStream = smaskStreamRef {
                    var df2 = CGPDFDataFormat.raw
                    if let smaskData = CGPDFStreamCopyData(smaskStream, &df2) {
                        if let src = CGImageSourceCreateWithData(smaskData, nil) {
                            alphaMask = CGImageSourceCreateImageAtIndex(src, 0, nil)
                        }
                        if alphaMask == nil {
                            var w: Int = 0
                            var h: Int = 0
                            var bpc: Int = 8
                            if let smDict = CGPDFStreamGetDictionary(smaskStream) {
                                _ = CGPDFDictionaryGetInteger(smDict, "Width", &w)
                                _ = CGPDFDictionaryGetInteger(smDict, "Height", &h)
                                _ = CGPDFDictionaryGetInteger(smDict, "BitsPerComponent", &bpc)
                            }
                            if let provider = CGDataProvider(data: smaskData) {
                                let gray = CGColorSpaceCreateDeviceGray()
                                let bytesPerRow = max(1, w * bpc / 8)
                                alphaMask = CGImage(width: w, height: h, bitsPerComponent: bpc, bitsPerPixel: bpc, bytesPerRow: bytesPerRow, space: gray, bitmapInfo: CGBitmapInfo(), provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
                            }
                        }
                    }
                }

                let w = finalImage.width
                let h = finalImage.height
                let cs = CGColorSpaceCreateDeviceRGB()
                guard let outCtx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
                let rect = CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h))
                outCtx.clear(rect)
                if let mask = alphaMask { outCtx.clip(to: rect, mask: mask) }
                outCtx.draw(finalImage, in: rect)
                guard let pngImage = outCtx.makeImage() else { return }
                let rep = NSBitmapImageRep(cgImage: pngImage)
                guard let data = rep.representation(using: .png, properties: [:]) else { return }
                let fname = String(format: "page_%03d_img_%03d.png", ctx.pageIndex, ctx.imageIndex + 1)
                let url = ctx.imagesDir.appendingPathComponent(fname)
                try? data.write(to: url)
                ctxPtr.pointee.imageIndex += 1
            }

            CGPDFOperatorTableSetCallback(table, "Do", unsafeBitCast(callback, to: CGPDFOperatorCallback.self))
            let cs = CGPDFContentStreamCreateWithPage(page)
            let ctx = ScannerContext(resources: resources, imagesDir: imagesDir, pageIndex: i)
            let ctxPtr = UnsafeMutablePointer<ScannerContext>.allocate(capacity: 1)
            ctxPtr.initialize(to: ctx)
            let scanner = CGPDFScannerCreate(cs, table, ctxPtr)
            _ = CGPDFScannerScan(scanner)
            ctxPtr.deinitialize(count: 1)
            ctxPtr.deallocate()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.pathExtension.lowercased() == "pdf" { process(pdfURL: url) }
        }
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.activate(ignoringOtherApps: true)
app.run()
