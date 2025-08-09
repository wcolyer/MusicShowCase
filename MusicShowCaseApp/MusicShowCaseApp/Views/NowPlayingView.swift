import SwiftUI

struct NowPlayingView: View {
    @StateObject private var viewModel = NowPlayingViewModel()
    @State private var hueRotation: Angle = .degrees(0)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [PaletteService.shared.current.start, PaletteService.shared.current.end],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .hueRotation(hueRotation)
            .ignoresSafeArea()

            // Constant ambient drift wall behind overlays
            ZuneWallBackground()

            // Interstitial artwork tile (never larger than 1/4 screen; respects image resolution)
            GeometryReader { geo in
                if let art = viewModel.interstitialArtwork {
                    let screen = geo.size
                    let maxTile = CGSize(width: screen.width * 0.35, height: screen.height * 0.35)
                    // Compute best-fit size under resolution and quarter-screen cap
                    let pixelW = art.cgImage?.width ?? Int(art.size.width * art.scale)
                    let pixelH = art.cgImage?.height ?? Int(art.size.height * art.scale)
                    let maxDisplayW = min(maxTile.width, CGFloat(pixelW))
                    let maxDisplayH = min(maxTile.height, CGFloat(pixelH))
                    let aspect = art.size.width / art.size.height
                    let targetW = min(maxDisplayW, maxDisplayH * aspect)
                    let targetH = targetW / aspect

                    Image(uiImage: art)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: targetW, height: targetH)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .modifier(ArtworkMotion())
                        .transition(.scale.combined(with: .opacity))
                        .position(x: screen.width * 0.78, y: screen.height * 0.70)
                }
            }

            overlayLane(viewModel.currentFactLane) {
                if let fact = viewModel.currentFact {
                    FactChip(text: fact.text)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)))
                        .id(fact.id)
                        .modifier(FloatJitter())
                }
            }
            .animation(.easeInOut(duration: 0.8), value: viewModel.currentFactLane)
            .animation(.easeInOut(duration: 0.6), value: viewModel.currentFact?.id)

            overlayLane(viewModel.currentNoteLane) {
                if let note = viewModel.currentNote {
                    NoteChip(text: note.text)
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity),
                                                removal: .opacity))
                        .id(note.id)
                        .modifier(FloatJitter())
                }
            }
            .animation(.easeInOut(duration: 0.8), value: viewModel.currentNoteLane)
            .animation(.easeInOut(duration: 0.6), value: viewModel.currentNote?.id)

            VStack { Spacer()
                Text("Now Playing")
                    .font(.title2.weight(.semibold))
                    .padding(.bottom, 24)
            }

            // Debug: show last artwork thumbnail at top-left
            if let img = PaletteService.shared.lastArtwork {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .onAppear {
            viewModel.start()
            let drift = Double.random(in: 40...60)
            if UIAccessibility.isReduceMotionEnabled {
                hueRotation = .degrees(0)
                print("[NowPlayingView] Reduce Motion ON: disabled hue drift")
            } else {
                withAnimation(.easeInOut(duration: drift).repeatForever(autoreverses: true)) {
                    hueRotation = .degrees(50)
                }
                print("[NowPlayingView] Hue drift duration=\(drift)s")
            }
            NotificationCenter.default.addObserver(forName: .init("ApplySimulatedNowPlayingItem"), object: nil, queue: .main) { note in
                if let item = note.object as? NowPlayingItem {
                    Task { @MainActor in
                        viewModel.applySimulatedNowPlaying(item: item)
                    }
                }
            }
        }
    }
}

private struct FloatJitter: ViewModifier {
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .offset(x: CGFloat(sin(Double(phase))) * 3,
                    y: CGFloat(cos(Double(phase) * 0.8)) * 3)
            .onAppear {
                let base = Double.random(in: 8...14)
                withAnimation(.easeInOut(duration: base).repeatForever(autoreverses: true)) {
                    phase = .pi * 2
                }
            }
    }
}

private struct ArtworkMotion: ViewModifier {
    @State private var t: CGFloat = 0
    func body(content: Content) -> some View {
        content
            // gentle drift, slight scale and hue shifts for drama
            .rotationEffect(.degrees(sin(Double(t)) * 2))
            .scaleEffect(1.0 + 0.02 * CGFloat(cos(Double(t) * 1.1)))
            .hueRotation(.degrees(sin(Double(t) * 0.7) * 6))
            .saturation(1.0 + 0.05 * CGFloat(sin(Double(t) * 0.9)))
            .onAppear {
                withAnimation(.easeInOut(duration: Double.random(in: 8...12)).repeatForever(autoreverses: true)) {
                    t = .pi * 2
                }
            }
    }
}

private struct FactChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.title3)
            .multilineTextAlignment(.center)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal)
    }
}

#Preview {
    NowPlayingView()
}

private extension NowPlayingView {
    @ViewBuilder
    func overlayLane<T: View>(_ lane: NowPlayingViewModel.OverlayLane, @ViewBuilder content: @escaping () -> T) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let marginX = size.width * 0.06
            let maxWidth = size.width * 0.5
            let half = maxWidth / 2
            let minCenterX = half + marginX
            let maxCenterX = size.width - half - marginX
            let position = position(for: lane, in: size, minCenterX: minCenterX, maxCenterX: maxCenterX)
            content()
                .frame(maxWidth: maxWidth)
                .fixedSize(horizontal: false, vertical: true)
                .position(position)
        }
    }

    func position(for lane: NowPlayingViewModel.OverlayLane, in size: CGSize, minCenterX: CGFloat, maxCenterX: CGFloat) -> CGPoint {
        // Centers are clamped so a view of width <= 50% never goes off-screen
        let leftX = minCenterX
        let rightX = maxCenterX
        let topY = size.height * 0.22
        let midY = size.height * 0.55
        let bottomY = size.height * 0.78
        switch lane {
        case .topLeft: return CGPoint(x: leftX, y: topY)
        case .topRight: return CGPoint(x: rightX, y: topY)
        case .bottomRight: return CGPoint(x: rightX, y: bottomY)
        case .bottomCenter: return CGPoint(x: size.width * 0.5, y: midY)
        }
    }
}

private struct NoteChip: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
            Text(text)
        }
        .font(.headline)
        .multilineTextAlignment(.center)
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

