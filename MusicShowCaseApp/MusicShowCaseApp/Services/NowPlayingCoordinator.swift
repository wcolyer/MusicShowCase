import Foundation

final class NowPlayingCoordinator: ObservableObject {
    // 0 = Now Playing, 1 = Listen Now, 2 = Library, 3 = Browse, 4 = Search, 5 = Settings
    @Published var selectedTab: Int = 0
    @Published var currentItem: NowPlayingItem?

    func simulatePlay(card: MediaCard) {
        #if targetEnvironment(simulator)
        let artist = card.subtitle ?? "Artist"
        self.currentItem = NowPlayingItem(title: card.title, artistName: artist, albumName: card.title, releaseYear: nil)
        // Switch tabs on next runloop tick to avoid fighting the focus engine
        DispatchQueue.main.async { [weak self] in self?.selectedTab = 0 }
        #endif
    }
}


