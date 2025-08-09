import Foundation

final class NowPlayingCoordinator: ObservableObject {
    // 0 = Now Playing, 1 = Listen Now, 2 = Library, 3 = Browse, 4 = Search, 5 = Settings
    @Published var selectedTab: Int = 0 {
        didSet {
            debug("selectedTab changed: \(oldValue) -> \(selectedTab) lockUntil=\(lockSelectionUntil?.timeIntervalSince1970 ?? -1) reason=\(lastSelectionChangeReason ?? "unknown")")
            #if DEBUG
            let stack = Thread.callStackSymbols.prefix(8).joined(separator: "\n")
            print("[Coordinator] callStack:\n\(stack)")
            #endif
            lastSelectionChangeReason = nil
        }
    }
    @Published var currentItem: NowPlayingItem?
    @Published var lockSelectionUntil: Date?
    private var lastSelectionChangeReason: String?

    // Debug helper to track when UI attempts to set selection directly
    func setSelectionFromUI(_ newValue: Int) {
        lastSelectionChangeReason = "ContentView.selectionBinding -> \(newValue)"
        selectedTab = newValue
    }

    func simulatePlay(card: MediaCard) {
        #if targetEnvironment(simulator)
        let artist = card.subtitle ?? "Artist"
        debug("simulatePlay tapped: title=\(card.title) artist=\(artist)")
        let before = selectedTab
        self.currentItem = NowPlayingItem(title: card.title, artistName: artist, albumName: card.title, releaseYear: nil)
        // Pin selection to Now Playing for a short period to absorb focus bounce
        self.lastSelectionChangeReason = "simulatePlay(title: \(card.title))"
        self.selectedTab = 0
        let until = Date().addingTimeInterval(1.0)
        self.lockSelectionUntil = until
        debug("simulatePlay set selectedTab: \(before) -> 0; lockSelectionUntil=\(until.timeIntervalSince1970)")
        NotificationCenter.default.post(name: .init("NowPlayingCoordinatorUpdated"), object: nil)
        debug("posted NowPlayingCoordinatorUpdated notification")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            self.debug("lock window expired; selectedTab=\(self.selectedTab)")
        }
        #endif
    }

    private func debug(_ message: String) {
        #if DEBUG
        let t = String(format: "%.3f", Date.timeIntervalSinceReferenceDate)
        print("[Coordinator] \(t): \(message)")
        #endif
    }
}


