import Foundation
import Combine

@MainActor
final class NowPlayingViewModel: ObservableObject {
    @Published private(set) var factsQueue: [Fact] = []
    @Published var currentFact: Fact?

    private var displayTimer: AnyCancellable?
    private let factsService: FactsServiceProtocol
    private let config: RemoteConfigService

    // Placeholder current track info; wire to MusicKit later
    var currentArtistName: String = "Daft Punk"
    var currentAlbumName: String = "Random Access Memories"
    var currentReleaseYear: Int = 2013

    init(factsService: FactsServiceProtocol = FactsService(), config: RemoteConfigService = .shared) {
        self.factsService = factsService
        self.config = config
    }

    func start() {
        Task { await config.fetchAndActivate() }
        Task { await prefetchInitialFacts() }
        scheduleNextDisplay()
    }

    private func prefetchInitialFacts() async {
        do {
            let initial = config.values.initialBatch
            let fetched = try await factsService.fetchFacts(
                artistName: currentArtistName,
                albumName: currentAlbumName,
                releaseYear: currentReleaseYear,
                max: initial
            )
            factsQueue.append(contentsOf: fetched)
        } catch {
            // keep empty; UI will no-op
        }
    }

    private func topUpIfNeeded() {
        guard factsQueue.count <= config.values.prefetchThreshold else { return }
        Task {
            do {
                let fetched = try await factsService.fetchFacts(
                    artistName: currentArtistName,
                    albumName: currentAlbumName,
                    releaseYear: currentReleaseYear,
                    max: config.values.topUpBatch
                )
                factsQueue.append(contentsOf: fetched)
            } catch { }
        }
    }

    private func scheduleNextDisplay() {
        let minInterval = TimeInterval(config.values.factMinIntervalSec)
        let maxInterval = TimeInterval(config.values.factMaxIntervalSec)
        let interval = Double.random(in: minInterval...maxInterval)

        displayTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.showNextFact()
                self.topUpIfNeeded()
                self.scheduleNextDisplay()
            }
    }

    private func showNextFact() {
        guard !factsQueue.isEmpty else { return }
        currentFact = factsQueue.removeFirst()
    }
}

