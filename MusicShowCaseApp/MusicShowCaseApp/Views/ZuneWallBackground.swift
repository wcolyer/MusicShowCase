import SwiftUI

struct Tile: Identifiable {
    let id = UUID()
    let baseX: CGFloat
    let baseY: CGFloat
    let ampX: CGFloat
    let ampY: CGFloat
    let speed: Double
    let size: CGSize
    let opacity: Double
    let phase: Double

    static func random(in rect: CGRect) -> Tile {
        let baseX = CGFloat.random(in: 0.05...0.95)
        let baseY = CGFloat.random(in: 0.10...0.90)
        let ampX = CGFloat.random(in: 0.06...0.12)
        let ampY = CGFloat.random(in: 0.04...0.10)
        let speed = Double.random(in: 0.05...0.12)
        let size = CGSize(width: CGFloat.random(in: 120...280), height: CGFloat.random(in: 120...280))
        let opacity = Double.random(in: 0.08...0.12)
        let phase = Double.random(in: 0...(2 * .pi))
        return Tile(baseX: baseX, baseY: baseY, ampX: ampX, ampY: ampY, speed: speed, size: size, opacity: opacity, phase: phase)
    }
}

final class ZuneWallModel: ObservableObject {
    let tiles: [Tile]
    init(tileCount: Int) {
        let dummyRect = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        self.tiles = (0..<tileCount).map { _ in Tile.random(in: dummyRect) }
    }
}

struct ZuneWallBackground: View {
    @StateObject private var model: ZuneWallModel

    init(tileCount: Int = 26) {
        _model = StateObject(wrappedValue: ZuneWallModel(tileCount: tileCount))
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                Canvas(rendersAsynchronously: true) { ctx, canvasSize in
                    for tile in model.tiles {
                        let x = (tile.baseX + CGFloat(cos((t * tile.speed) + tile.phase)) * tile.ampX) * size.width
                        let y = (tile.baseY + CGFloat(sin((t * tile.speed * 0.85) + tile.phase)) * tile.ampY) * size.height
                        var rect = CGRect(origin: .zero, size: tile.size)
                        rect.origin = CGPoint(x: x - rect.size.width / 2, y: y - rect.size.height / 2)

                        let path = Path(roundedRect: rect, cornerRadius: 18)
                        ctx.opacity = tile.opacity
                        ctx.addFilter(.blur(radius: 2))
                        ctx.fill(path, with: .color(.white))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
    }
}
