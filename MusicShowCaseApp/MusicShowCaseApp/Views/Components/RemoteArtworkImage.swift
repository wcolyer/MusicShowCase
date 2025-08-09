import SwiftUI

final class ArtworkImageCache {
    static let shared = ArtworkImageCache()
    private let cache = NSCache<NSString, UIImage>()
    func image(forKey key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func insert(_ image: UIImage, forKey key: String) { cache.setObject(image, forKey: key as NSString) }
}

struct RemoteArtworkImage: View {
    let urlString: String?
    let size: CGSize
    let cornerRadius: CGFloat
    // Optional fallback search parameters (iTunes Search)
    let fallbackArtist: String?
    let fallbackAlbumOrTitle: String?

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
            if let image {
                Image(uiImage: image)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .onAppear(perform: load)
    }

    private func load() {
        guard !isLoading else { return }
        guard let urlString, let url = URL(string: urlString) else {
            // Try search fallback only
            #if DEBUG
            print("[TileArtwork] no direct URL; using search for artist=\(fallbackArtist ?? "-") term=\(fallbackAlbumOrTitle ?? "-")")
            #endif
            Task { await fetchViaSearch() }
            return
        }
        #if DEBUG
        print("[TileArtwork] fetching direct: \(url.absoluteString)")
        #endif
        if let cached = ArtworkImageCache.shared.image(forKey: urlString) {
            self.image = cached
            return
        }
        isLoading = true
        Task {
            do {
                let data = try await ArtworkService.shared.fetchDirect(url: url)
                if let img = UIImage(data: data) {
                    ArtworkImageCache.shared.insert(img, forKey: urlString)
                    await MainActor.run { self.image = img }
                    #if DEBUG
                    print("[TileArtwork] set image from direct: \(url.absoluteString)")
                    #endif
                }
            } catch {
                #if DEBUG
                print("[TileArtwork] direct fetch failed: \(error.localizedDescription); falling back to search")
                #endif
                await fetchViaSearch()
            }
            isLoading = false
        }
    }

    private func fetchViaSearch() async {
        guard let artist = fallbackArtist, let albumOrTitle = fallbackAlbumOrTitle else { return }
        if let data = await ArtworkService.shared.fetchArtworkData(artistName: artist, albumName: albumOrTitle, title: nil),
           let img = UIImage(data: data) {
            ArtworkImageCache.shared.insert(img, forKey: "search::\(artist)::\(albumOrTitle)")
            await MainActor.run { self.image = img }
        } else {
            #if DEBUG
            print("[TileArtwork] search fallback failed for artist=\(artist) term=\(albumOrTitle)")
            #endif
        }
    }
}


