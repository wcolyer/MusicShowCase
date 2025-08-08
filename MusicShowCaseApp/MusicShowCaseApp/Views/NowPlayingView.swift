import SwiftUI

struct NowPlayingView: View {
    @StateObject private var viewModel = NowPlayingViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

            overlayLane(viewModel.currentFactLane) {
                if let fact = viewModel.currentFact {
                    FactChip(text: fact.text)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            overlayLane(viewModel.currentNoteLane) {
                if let note = viewModel.currentNote {
                    NoteChip(text: note.text)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            VStack { Spacer() 
                Text("Now Playing")
                    .font(.title2.weight(.semibold))
                    .padding(.bottom, 24)
            }
        }
        .onAppear { viewModel.start() }
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
            let position = position(for: lane, in: proxy.size)
            content()
                .position(position)
        }
    }

    func position(for lane: NowPlayingViewModel.OverlayLane, in size: CGSize) -> CGPoint {
        switch lane {
        case .topLeft: return CGPoint(x: size.width * 0.2, y: size.height * 0.2)
        case .topRight: return CGPoint(x: size.width * 0.8, y: size.height * 0.2)
        case .bottomRight: return CGPoint(x: size.width * 0.8, y: size.height * 0.8)
        case .bottomCenter: return CGPoint(x: size.width * 0.5, y: size.height * 0.8)
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

