import AppKit
import CoreGraphics

func createAppIcon() {
    let iconsetURL = URL(fileURLWithPath: "AppIcon.iconset")
    try? FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true, attributes: nil)
    
    let sizes = [16, 32, 128, 256, 512]
    
    for size in sizes {
        for scale in [1, 2] {
            let pixelSize = size * scale
            let filename = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
            
            let rect = CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
            let image = NSImage(size: rect.size)
            image.lockFocus()
            
            guard let context = NSGraphicsContext.current?.cgContext else { continue }
            
            // Draw background squircle
            let path = NSBezierPath(roundedRect: rect, xRadius: CGFloat(pixelSize) * 0.225, yRadius: CGFloat(pixelSize) * 0.225)
            NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.12, alpha: 1.0).setFill() // Dark background
            path.fill()
            
            // Draw SF Symbol
            let config = NSImage.SymbolConfiguration(pointSize: CGFloat(pixelSize) * 0.5, weight: .regular)
            if let symbolImage = NSImage(systemSymbolName: "play.laptopcomputer", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                // Tint to white
                symbolImage.lockFocus()
                NSColor.white.set()
                let imageRect = NSRect(origin: .zero, size: symbolImage.size)
                imageRect.fill(using: .sourceAtop)
                symbolImage.unlockFocus()
                
                let drawRect = CGRect(
                    x: (CGFloat(pixelSize) - symbolImage.size.width) / 2,
                    y: (CGFloat(pixelSize) - symbolImage.size.height) / 2,
                    width: symbolImage.size.width,
                    height: symbolImage.size.height
                )
                symbolImage.draw(in: drawRect)
            }
            
            image.unlockFocus()
            
            if let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                let fileURL = iconsetURL.appendingPathComponent(filename)
                try? pngData.write(to: fileURL)
            }
        }
    }
}

createAppIcon()
print("AppIcon.iconset generated.")
