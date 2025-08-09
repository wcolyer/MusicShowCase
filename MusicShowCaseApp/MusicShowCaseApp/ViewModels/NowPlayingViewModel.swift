import Foundation
import Combine
import SwiftUI

@MainActor
final class NowPlayingViewModel: ObservableObject {
    enum OverlayLane: CaseIterable { case topLeft, topRight, bottomRight, bottomCenter }

    @Published private(set) var factsQueue: [Fact] = []
    @Published var currentFact: Fact?
    @Published var currentNote: EditorialNote?
    @Published var interstitialArtwork: UIImage?
    @Published var currentFactLane: OverlayLane = .bottomCenter
    @Published var currentNoteLane: OverlayLane = .topLeft

    private var factTimer: AnyCancellable?
    private var hideFactTask: Task<Void, Never>?
    private var factsSinceArtworkChange: Int = 0
    private var noteTimer: AnyCancellable?
    private var lastFactShownAt: Date?
    private var lastNoteShownAt: Date?
    private var lastUsedFactLane: OverlayLane?
    private var lastUsedNoteLane: OverlayLane?
    private var lastArtworkKey: String?
    private var artworkImages: [UIImage] = []
    private var artworkIndex: Int = 0
    private var artworkMeta: [(image: UIImage, pixelSize: CGSize)] = []

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
            // Collect multiple artwork candidates for interstitial display
            let candidates = await ArtworkService.shared.fetchArtworkCandidates(
                artistName: currentArtistName,
                albumName: currentAlbumName,
                title: nil,
                max: 6
            )
            let images = candidates.compactMap { UIImage(data: $0) }
            let meta = images.map { ($0, CGSize(width: $0.cgImage?.width ?? Int($0.size.width * $0.scale), height: $0.cgImage?.height ?? Int($0.size.height * $0.scale))) }
            await MainActor.run {
                self.artworkImages = images
                self.artworkMeta = meta
            }
        } catch { }
        if currentFact == nil, !factsQueue.isEmpty {
            withAnimation(.easeInOut(duration: 0.6)) {
                currentFact = factsQueue.removeFirst()
            }
            updateArtworkIfNeeded()
            factsSinceArtworkChange = 0
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
                // Optionally show an artwork interstitial instead of a fact
                if self.shouldShowArtworkInterstitial() {
                    self.showArtworkInterstitial()
                    self.scheduleFacts()
                    return
                }
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
        // Ensure any artwork interstitial is hidden
        if interstitialArtwork != nil { interstitialArtwork = nil }
        withAnimation(.easeInOut(duration: 0.6)) {
            currentFact = factsQueue.removeFirst()
            // Facts should dwell mid/top, not bottom
            currentFactLane = nextFactLane(previous: lastUsedFactLane)
        }
        lastUsedFactLane = currentFactLane
        lastFactShownAt = Date()
        debug("fact shown lane=\(currentFactLane)")

        // Rotate artwork image occasionally to keep visuals fresh
        factsSinceArtworkChange += 1
        if shouldAdvanceArtwork() {
            lastArtworkKey = nil
            updateArtworkIfNeeded()
            factsSinceArtworkChange = 0
            debug("advanced artwork after facts=")
        }

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

    private func shouldShowArtworkInterstitial() -> Bool {
        guard !artworkImages.isEmpty else { return false }
        // Do not overlap with fact display
        if currentFact != nil { return false }
        // Respect separation from notes
        if let lastNote = lastNoteShownAt, Date().timeIntervalSince(lastNote) < 6 { return false }
        // Frequency based on available images
        switch artworkImages.count {
        case 4...: return Bool.random() // ~50%
        case 2...3: return Int.random(in: 0...2) == 0 // ~33%
        default: return Int.random(in: 0...4) == 0 // ~20%
        }
    }

    private func showArtworkInterstitial() {
        guard !artworkImages.isEmpty else { return }
        let image = artworkImages[artworkIndex % artworkImages.count]
        artworkIndex += 1
        withAnimation(.easeInOut(duration: 0.5)) {
            interstitialArtwork = image
        }
        let dwell = Double.random(in: 2.5...3.5)
        Task { [weak self] in
            guard let self else { return }
            do { try await Task.sleep(nanoseconds: UInt64(dwell * 1_000_000_000)) } catch { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.interstitialArtwork = nil
                }
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
    private func shouldAdvanceArtwork() -> Bool {
        // Every 4-5 facts, or more often if multiple palettes are available for current art
        // If PaletteService found many palettes, bias toward more frequent changes
        let paletteCount = PaletteService.shared.paletteCount
        if paletteCount >= 4 {
            // change about every 3 facts
            return factsSinceArtworkChange >= Int.random(in: 3...4)
        } else if paletteCount >= 2 {
            // change every 4-5 facts
            return factsSinceArtworkChange >= Int.random(in: 4...5)
        } else {
            // only one palette; change less frequently
            return factsSinceArtworkChange >= Int.random(in: 5...7)
        }
    }

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

