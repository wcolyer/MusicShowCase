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

            VStack(spacing: 24) {
                Text("Now Playing")
                    .font(.largeTitle.weight(.bold))

                if let fact = viewModel.currentFact {
                    FactChip(text: fact.text)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Text("Fetching fun facts…")
                        .foregroundStyle(.secondary)
                }
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

