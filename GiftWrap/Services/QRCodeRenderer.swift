import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum QRCodeRenderer {

    /// Crisp, upscaled QR for print-ready cards. Returns nil for empty input.
    static func image(from string: String, size: CGFloat = 512) -> NSImage? {
        guard !string.isEmpty else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }

        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }

    static func pngData(from string: String, size: CGFloat = 512) -> Data? {
        guard let image = image(from: string, size: size),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
