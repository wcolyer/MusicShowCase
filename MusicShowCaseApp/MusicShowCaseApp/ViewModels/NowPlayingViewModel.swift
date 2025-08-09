import Foundation
import Combine
import SwiftUI

@MainActor
final class NowPlayingViewModel: ObservableObject {
    enum OverlayLane: CaseIterable { case topLeft, topRight, bottomRight, bottomCenter }

    @Published private(set) var factsQueue: [Fact] = []
    @Published var currentFact: Fact?
    @Published var currentNote: EditorialNote?
    @Published var currentFactLane: OverlayLane = .bottomCenter
    @Published var currentNoteLane: OverlayLane = .topLeft

    private var factTimer: AnyCancellable?
    private var hideFactTask: Task<Void, Never>?
    private var noteTimer: AnyCancellable?
    private var lastFactShownAt: Date?
    private var lastNoteShownAt: Date?
    private var lastUsedFactLane: OverlayLane?
    private var lastUsedNoteLane: OverlayLane?
    private var lastArtworkKey: String?

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

    private var hasStarted = false

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        debug("start()")
        Task {
            await config.fetchAndActivate()
            try? await appleMusic.requestAuthorizationIfNeeded()
            await refreshFromNowPlaying()
            await prefetchInitialFacts()
        }
        scheduleFacts()
        scheduleNotes()
    }

    func applySimulatedNowPlaying(item: NowPlayingItem) {
        currentArtistName = item.artistName
        currentAlbumName = item.albumName
        currentReleaseYear = item.releaseYear ?? currentReleaseYear
        factsQueue.removeAll()
        currentFact = nil
        lastArtworkKey = nil
        updateArtworkIfNeeded()
        Task { await prefetchInitialFacts() }
    }

    private func refreshFromNowPlaying() async {
        if let now = await appleMusic.currentNowPlaying() {
            currentArtistName = now.artistName
            currentAlbumName = now.albumName
            currentReleaseYear = now.releaseYear ?? currentReleaseYear
            debug("NowPlaying: artist=\(currentArtistName) album=\(currentAlbumName) year=\(currentReleaseYear)")
        } else {
            debug("NowPlaying: no item")
        }
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
        if currentFact == nil, !factsQueue.isEmpty {
            withAnimation(.easeInOut(duration: 0.6)) {
                currentFact = factsQueue.removeFirst()
            }
            updateArtworkIfNeeded()
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

    private func scheduleFacts() {
        // Near-continuous flow: dwell 3–5s, short buffer
        let insertionDuration: Double = 0.6
        let dwell = Double.random(in: 3...5)
        let interval = insertionDuration + dwell + 0.3
        debug("scheduleFacts: dwell=\(String(format: "%.1f", dwell))s in=\(String(format: "%.1f", interval))s")

        factTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.debug("fact timer fired")
                // Enforce 6s separation from notes
                if let lastNote = self.lastNoteShownAt, Date().timeIntervalSince(lastNote) < 6 {
                    self.debug("skip fact due to 6s separation from note")
                    self.scheduleFacts()
                    return
                }
                self.showNextFact(dwell: dwell)
                self.topUpIfNeeded()
                self.scheduleFacts()
            }
    }

    private func scheduleNotes() {
        guard config.values.enableEditorial else { return }
        let minInterval = TimeInterval(config.values.chipMinIntervalSec)
        let maxInterval = TimeInterval(config.values.chipMaxIntervalSec)
        let interval = Double.random(in: minInterval...maxInterval)
        debug("scheduleNotes in \(String(format: "%.1f", interval))s")

        noteTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.debug("note timer fired")
                Task { [weak self] in
                    guard let self else { return }
                    // Enforce 6s separation from facts
                    if let lastFact = self.lastFactShownAt, Date().timeIntervalSince(lastFact) < 6 {
                        self.debug("skip note due to 6s separation from fact")
                        self.scheduleNotes()
                        return
                    }
                    let note = await self.appleMusic.currentEditorialNote()
                    withAnimation(.easeInOut(duration: 0.6)) {
                        self.currentNote = note
                        self.currentNoteLane = self.nextLane(excluding: self.lastUsedNoteLane)
                    }
                    self.debug("note shown lane=\(self.currentNoteLane)")
                    self.lastUsedNoteLane = self.currentNoteLane
                    self.lastNoteShownAt = Date()
                    self.scheduleNotes()
                }
            }
    }

    private func showNextFact(dwell: Double? = nil) {
        guard !factsQueue.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.6)) {
            currentFact = factsQueue.removeFirst()
            // Facts should dwell mid/top, not bottom
            currentFactLane = nextFactLane(previous: lastUsedFactLane)
        }
        lastUsedFactLane = currentFactLane
        lastFactShownAt = Date()
        debug("fact shown lane=\(currentFactLane)")

        updateArtworkIfNeeded()

        // Schedule hide after dwell (3–5s by default if not provided)
        hideFactTask?.cancel()
        let dwellSeconds = dwell ?? Double.random(in: 3...5)
        hideFactTask = Task { [weak self] in
            guard let self else { return }
            let insertionDuration: Double = 0.6
            do {
                try await Task.sleep(nanoseconds: UInt64((dwellSeconds + insertionDuration) * 1_000_000_000))
            } catch {
                self.debug("hide task canceled before sleep finished")
                return
            }
            guard !Task.isCancelled else {
                self.debug("hide task canceled flag set")
                return
            }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.currentFact = nil
                }
                self.debug("fact hidden after dwell=\(String(format: "%.1f", dwellSeconds))s")
            }
        }
    }

    private func nextFactLane(previous: OverlayLane?) -> OverlayLane {
        // Always choose a top lane for facts to avoid dwelling at the bottom
        let topLanes: [OverlayLane] = [.topLeft, .topRight]
        // Alternate if possible
        if previous == .topLeft { return .topRight }
        if previous == .topRight { return .topLeft }
        return topLanes.randomElement() ?? .topLeft
    }

    private func nextLane(excluding last: OverlayLane?) -> OverlayLane {
        // Generic alternation used by notes
        let all = OverlayLane.allCases
        guard let last else { return all.randomElement() ?? .bottomCenter }
        let candidates = all.filter { $0 != last }
        return candidates.randomElement() ?? .bottomCenter
    }

    private func debug(_ message: String) {
        #if DEBUG
        let ts = String(format: "%.3f", Date().timeIntervalSince1970)
        print("[NowPlayingVM] \(ts): \(message)")
        #endif
    }
}

extension NowPlayingViewModel {
    private func updateArtworkIfNeeded() {
        let artworkKey = "\(currentArtistName.lowercased())|\(currentAlbumName.lowercased())"
        guard artworkKey != lastArtworkKey else { return }
        lastArtworkKey = artworkKey
        Task.detached { [artist = currentArtistName, album = currentAlbumName] in
            if let data = await ArtworkService.shared.fetchArtworkData(artistName: artist, albumName: album, title: nil) {
                await MainActor.run { PaletteService.shared.updateForArtwork(data) }
            }
        }
    }
}

