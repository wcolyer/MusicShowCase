import Foundation
import SwiftUI
import CoreImage
import UIKit

struct Palette: Equatable {
    let start: Color
    let end: Color
}

final class PaletteService: ObservableObject {
    static let shared = PaletteService()
    @Published private(set) var current: Palette = Palette(start: .purple.opacity(0.6), end: .blue.opacity(0.6))
    @Published var lastArtwork: UIImage?

    private init() {}

    func updateForArtwork(_ data: Data?) {
        guard let data, let uiImage = UIImage(data: data), let cgImage = uiImage.cgImage else { return }
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        let ciContext = CIContext(options: [.workingColorSpace: NSNull()])
        guard let filter = CIFilter(name: "CIAreaAverage") else { return }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: extent.origin.x, y: extent.origin.y, z: extent.size.width, w: extent.size.height), forKey: kCIInputExtentKey)
        guard let output = filter.outputImage else { return }
        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(output, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        let r = Double(bitmap[0]) / 255.0
        let g = Double(bitmap[1]) / 255.0
        let b = Double(bitmap[2]) / 255.0
        let a = Double(bitmap[3]) / 255.0
        let base = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
        // Create a complementary end color by slightly shifting hue/brightness
        let start = base.opacity(0.85)
        let end = base.mix(with: .black, by: 0.35).opacity(0.85)
        withAnimation(.easeInOut(duration: 1.0)) {
            self.current = Palette(start: start, end: end)
            self.lastArtwork = uiImage
        }
    }
}

private extension Color {
    func mix(with other: Color, by fraction: CGFloat) -> Color {
        let f = max(0, min(1, fraction))
        let u = UIColor(self)
        let v = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        u.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        v.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(red: Double(r1 + (r2 - r1) * f),
                     green: Double(g1 + (g2 - g1) * f),
                     blue: Double(b1 + (b2 - b1) * f),
                     opacity: Double(a1 + (a2 - a1) * f))
    }
}

