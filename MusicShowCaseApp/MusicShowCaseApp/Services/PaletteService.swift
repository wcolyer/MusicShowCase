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
    @Published private(set) var paletteCount: Int = 1

    private var paletteSequence: [Palette] = []
    private var sequenceIndex: Int = 0
    private var cycleTimer: Timer?

    private init() {}

    func updateForArtwork(_ data: Data?) {
        guard let data, let uiImage = UIImage(data: data), let cgImage = uiImage.cgImage else { return }
        let ciImage = CIImage(cgImage: cgImage)
        // Build a sequence of palettes from multiple regions of the image
        self.paletteSequence = Self.buildPaletteSequence(from: ciImage)
        self.sequenceIndex = 0
        if let first = self.paletteSequence.first {
            withAnimation(.easeInOut(duration: 1.0)) {
                self.current = first
                self.lastArtwork = uiImage
            }
        }
        self.paletteCount = max(1, self.paletteSequence.count)
        scheduleNextCycle()
    }

    func updateForMultipleArtworks(_ images: [Data]) {
        // Build palettes across multiple images to increase variety
        var allPalettes: [Palette] = []
        for data in images {
            if let ui = UIImage(data: data), let cg = ui.cgImage {
                let ci = CIImage(cgImage: cg)
                allPalettes.append(contentsOf: Self.buildPaletteSequence(from: ci))
            }
        }
        if allPalettes.isEmpty { return }
        self.paletteSequence = allPalettes
        self.paletteCount = allPalettes.count
        self.sequenceIndex = 0
        withAnimation(.easeInOut(duration: 1.0)) {
            self.current = allPalettes.first!
        }
        scheduleNextCycle()
    }

    private func scheduleNextCycle() {
        cycleTimer?.invalidate()
        guard paletteSequence.count > 1 else { return } // No need to cycle if only one color
        let interval = Double.random(in: 15.0...20.0)
        debug("scheduleNextCycle in \(String(format: "%.1f", interval))s (count=\(paletteSequence.count))")
        cycleTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.sequenceIndex = (self.sequenceIndex + 1) % self.paletteSequence.count
            let next = self.paletteSequence[self.sequenceIndex]
            withAnimation(.easeInOut(duration: 1.0)) {
                self.current = next
            }
            self.scheduleNextCycle()
        }
        RunLoop.main.add(cycleTimer!, forMode: .common)
    }

    private static func buildPaletteSequence(from image: CIImage) -> [Palette] {
        // Saturation-weighted HSV histogram quantization for punchier colors
        let targetSize = CGSize(width: 64, height: 64)
        let extent = image.extent
        let scaleX = targetSize.width / max(1, extent.width)
        let scaleY = targetSize.height / max(1, extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        let context = CIContext(options: [.workingColorSpace: NSNull()])

        var pixels = [UInt8](repeating: 0, count: Int(targetSize.width * targetSize.height * 4))
        context.render(scaled,
                       toBitmap: &pixels,
                       rowBytes: Int(targetSize.width) * 4,
                       bounds: CGRect(origin: .zero, size: targetSize),
                       format: .RGBA8,
                       colorSpace: nil)

        struct BinAgg { var r: Double = 0; var g: Double = 0; var b: Double = 0; var w: Double = 0 }
        var bins: [Int: BinAgg] = [:]
        let hBins = 24, sBins = 3, vBins = 3

        func binKey(h: CGFloat, s: CGFloat, v: CGFloat) -> Int {
            let hi = min(max(Int(floor(h * CGFloat(hBins))), 0), hBins - 1)
            let si = min(max(Int(floor(s * CGFloat(sBins))), 0), sBins - 1)
            let vi = min(max(Int(floor(v * CGFloat(vBins))), 0), vBins - 1)
            return (hi << 8) | (si << 4) | vi
        }

        for y in 0..<Int(targetSize.height) {
            for x in 0..<Int(targetSize.width) {
                let idx = (y * Int(targetSize.width) + x) * 4
                let r = CGFloat(pixels[idx + 0]) / 255.0
                let g = CGFloat(pixels[idx + 1]) / 255.0
                let b = CGFloat(pixels[idx + 2]) / 255.0
                let a = CGFloat(pixels[idx + 3]) / 255.0
                guard a > 0.01 else { continue }
                let ui = UIColor(red: r, green: g, blue: b, alpha: 1)
                var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, _a: CGFloat = 0
                ui.getHue(&h, saturation: &s, brightness: &v, alpha: &_a)
                if s < 0.18 || v < 0.22 { continue }
                let w = Double(s * s * v) // favor punchy colors
                let key = binKey(h: h, s: s, v: v)
                var agg = bins[key] ?? BinAgg()
                agg.r += Double(r) * w
                agg.g += Double(g) * w
                agg.b += Double(b) * w
                agg.w += w
                bins[key] = agg
            }
        }

        let clusters: [(color: UIColor, score: Double)] = bins.compactMap { _, agg in
            guard agg.w > 0 else { return nil }
            let r = CGFloat(agg.r / agg.w)
            let g = CGFloat(agg.g / agg.w)
            let b = CGFloat(agg.b / agg.w)
            return (UIColor(red: r, green: g, blue: b, alpha: 1), agg.w)
        }.sorted { $0.score > $1.score }

        // Pick top distinct clusters
        var chosen: [UIColor] = []
        let maxColors = 6
        let distinctThreshold: CGFloat = 0.2
        for c in clusters {
            if chosen.count >= maxColors { break }
            if chosen.contains(where: { rgbDistance($0, c.color) < distinctThreshold }) { continue }
            chosen.append(c.color)
        }

        if chosen.isEmpty {
            let base = Color(.sRGB, red: 0.4, green: 0.3, blue: 0.7, opacity: 0.85)
            return [Palette(start: base, end: base.mix(with: .black, by: 0.35))]
        }

        let palettes: [Palette] = chosen.map { ui in
            let base = Color(ui)
            let start = base.opacity(0.90)
            let end = base.mix(with: .black, by: 0.45).opacity(0.90) // deepen contrast for drama
            return Palette(start: start, end: end)
        }
        return palettes
    }

    private static func rgbDistance(_ a: UIColor, _ b: UIColor) -> CGFloat {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let dr = ar - br, dg = ag - bg, db = ab - bb
        return sqrt(dr*dr + dg*dg + db*db)
    }

    private func debug(_ message: String) {
        #if DEBUG
        print("[Palette] \(message)")
        #endif
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

