import Foundation
import Combine

@MainActor
final class NowPlayingViewModel: ObservableObject {
    enum OverlayLane: CaseIterable { case topLeft, topRight, bottomRight, bottomCenter }

    @Published private(set) var factsQueue: [Fact] = []
    @Published var currentFact: Fact?
    @Published var currentNote: EditorialNote?
    @Published var currentFactLane: OverlayLane = .bottomCenter
    @Published var currentNoteLane: OverlayLane = .topLeft

    private var factTimer: AnyCancellable?
    private var noteTimer: AnyCancellable?
    private var lastFactShownAt: Date?
    private var lastNoteShownAt: Date?
    private var lastUsedFactLane: OverlayLane?
    private var lastUsedNoteLane: OverlayLane?

    private let factsService: FactsServiceProtocol
    private let config: RemoteConfigService
    private let appleMusic: AppleMusicServiceProtocol

    // Placeholder current track info; wire to MusicKit later
    var currentArtistName: String = "Daft Punk"
    var currentAlbumName: String = "Random Access Memories"
    var currentReleaseYear: Int = 2013

    init(
        factsService: FactsServiceProtocol = FactsService(),
        config: RemoteConfigService = .shared,
        appleMusic: AppleMusicServiceProtocol = AppleMusicService()
    ) {
        self.factsService = factsService
        self.config = config
        self.appleMusic = appleMusic
    }

    func start() {
        Task { await config.fetchAndActivate() }
        Task { await prefetchInitialFacts() }
        scheduleFacts()
        scheduleNotes()
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
        } catch { }
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

    private func scheduleFacts() {
        let minInterval = TimeInterval(config.values.factMinIntervalSec)
        let maxInterval = TimeInterval(config.values.factMaxIntervalSec)
        let interval = Double.random(in: minInterval...maxInterval)

        factTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                // Enforce 6s separation from notes
                if let lastNote = self.lastNoteShownAt, Date().timeIntervalSince(lastNote) < 6 {
                    self.scheduleFacts()
                    return
                }
                self.showNextFact()
                self.topUpIfNeeded()
                self.scheduleFacts()
            }
    }

    private func scheduleNotes() {
        guard config.values.enableEditorial else { return }
        let minInterval = TimeInterval(config.values.chipMinIntervalSec)
        let maxInterval = TimeInterval(config.values.chipMaxIntervalSec)
        let interval = Double.random(in: minInterval...maxInterval)

        noteTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { [weak self] in
                    guard let self else { return }
                    // Enforce 6s separation from facts
                    if let lastFact = self.lastFactShownAt, Date().timeIntervalSince(lastFact) < 6 {
                        self.scheduleNotes()
                        return
                    }
                    self.currentNote = await self.appleMusic.currentEditorialNote()
                    self.currentNoteLane = self.nextLane(excluding: self.lastUsedNoteLane)
                    self.lastUsedNoteLane = self.currentNoteLane
                    self.lastNoteShownAt = Date()
                    self.scheduleNotes()
                }
            }
    }

    private func showNextFact() {
        guard !factsQueue.isEmpty else { return }
        currentFact = factsQueue.removeFirst()
        currentFactLane = nextLane(excluding: lastUsedFactLane)
        lastUsedFactLane = currentFactLane
        lastFactShownAt = Date()
    }

    private func nextLane(excluding last: OverlayLane?) -> OverlayLane {
        let all = OverlayLane.allCases
        guard let last else { return all.randomElement() ?? .bottomCenter }
        let candidates = all.filter { $0 != last }
        return candidates.randomElement() ?? .bottomCenter
    }
}

