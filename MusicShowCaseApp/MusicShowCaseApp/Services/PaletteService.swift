import Foundation
import SwiftUI

struct Palette: Equatable {
    let start: Color
    let end: Color
}

final class PaletteService: ObservableObject {
    static let shared = PaletteService()
    @Published private(set) var current: Palette = Palette(start: .purple.opacity(0.6), end: .blue.opacity(0.6))

    private init() {}

    func updateForArtwork(_ data: Data?) {
        // Stub: in future, extract dominant colors with CoreImage/Accelerate
        withAnimation(.easeInOut(duration: 1.0)) {
            current = Palette(start: .purple.opacity(0.6), end: .blue.opacity(0.6))
        }
    }
}

