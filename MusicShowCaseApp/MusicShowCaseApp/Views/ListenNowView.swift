import SwiftUI

struct ListenNowView: View {
    @EnvironmentObject private var coordinator: NowPlayingCoordinator
    @State private var sections: [SectionOfCards] = []
    private let music: AppleMusicServiceProtocol = AppleMusicService()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section.title)
                            .font(.title2.weight(.semibold))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(section.items) { item in
                                    Button(action: { coordinator.simulatePlay(card: item) }) {
                                        MediaCardView(title: item.title, subtitle: item.subtitle, artworkURL: item.artworkURL)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 32)
        }
        .onAppear {
            Task { sections = await music.listenNowSections() }
        }
    }
}

private struct MediaCardView: View {
    let title: String
    let subtitle: String?
    let artworkURL: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                // Prefer iTunes Search (tiles) to avoid ephemeral direct URLs
                RemoteArtworkImage(urlString: nil, size: CGSize(width: 320, height: 320), cornerRadius: 12, fallbackArtist: subtitle, fallbackAlbumOrTitle: title)
                    .zIndex(1)
            }
            Text(title).font(.headline)
            if let subtitle { Text(subtitle).foregroundStyle(.secondary) }
        }
        .frame(width: 320)
    }
}

