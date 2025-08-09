import Foundation

protocol AppleMusicServiceProtocol {
    func requestAuthorizationIfNeeded() async throws
    func currentNowPlaying() async -> NowPlayingItem?
    func currentEditorialNote() async -> EditorialNote?
    func listenNowSections() async -> [SectionOfCards]
    func browseSections() async -> [SectionOfCards]
}

#if canImport(MusicKit)
import MusicKit

final class AppleMusicService: AppleMusicServiceProtocol {
    // Simulator: return stubbed data so we can build UI/flows without Apple Music
    #if targetEnvironment(simulator)
    func requestAuthorizationIfNeeded() async throws { /* no-op in simulator */ }
    func currentNowPlaying() async -> NowPlayingItem? {
        return NowPlayingItem(
            title: "Get Lucky",
            artistName: "Daft Punk",
            albumName: "Random Access Memories",
            releaseYear: 2013
        )
    }
    func currentEditorialNote() async -> EditorialNote? { nil }
    func listenNowSections() async -> [SectionOfCards] {
        return [
            SectionOfCards(id: "recent", title: "Recently Played", items: demoAlbums_recent()),
            SectionOfCards(id: "heavy", title: "Heavy Rotation", items: demoAlbums_heavy()),
            SectionOfCards(id: "recommend", title: "Because You Like", items: demoAlbums_recommended())
        ]
    }
    func browseSections() async -> [SectionOfCards] {
        return [
            SectionOfCards(id: "charts", title: "Top Charts", items: demoAlbums_charts()),
            SectionOfCards(id: "genres", title: "Featured Genres", items: demoAlbums_genres()),
            SectionOfCards(id: "curated", title: "Curated Playlists", items: demoPlaylists_curated())
        ]
    }
    private func mediaCard(id: String, title: String, subtitle: String, artwork: String) -> MediaCard {
        MediaCard(id: id, title: title, subtitle: subtitle, artworkURL: artwork)
    }
    private func demoAlbums_recent() -> [MediaCard] {
        return [
            mediaCard(id: "ram", title: "Random Access Memories", subtitle: "Daft Punk",
                      artwork: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/f2/96/88/f29688d9-3d2f-6af6-7b98-5d6c930b7f35/886443919167.jpg/1000x1000bb.jpg"),
            mediaCard(id: "blonde", title: "Blonde", subtitle: "Frank Ocean",
                      artwork: "https://is2-ssl.mzstatic.com/image/thumb/Music115/v4/2d/73/60/2d736071-4b53-84b0-4454-0e7d7f5a51cb/Blonde.jpg/1000x1000bb.jpg"),
            mediaCard(id: "am", title: "AM", subtitle: "Arctic Monkeys",
                      artwork: "https://is2-ssl.mzstatic.com/image/thumb/Music115/v4/c5/f9/5b/c5f95b62-2bd4-34af-0ed3-9f94a515786e/886443735014.jpg/1000x1000bb.jpg")
        ]
    }
    private func demoAlbums_heavy() -> [MediaCard] {
        return [
            mediaCard(id: "tpab", title: "To Pimp a Butterfly", subtitle: "Kendrick Lamar",
                      artwork: "https://is4-ssl.mzstatic.com/image/thumb/Music125/v4/6d/2b/2a/6d2b2a0b-4a61-d1db-2f75-3b6c5c770585/00602547228315.rgb.jpg/1000x1000bb.jpg"),
            mediaCard(id: "moon", title: "In Rainbows", subtitle: "Radiohead",
                      artwork: "https://is3-ssl.mzstatic.com/image/thumb/Music115/v4/7a/1d/3d/7a1d3df6-0f7d-67a4-1dc2-5a7a7c0d4d8e/00850311122284.rgb.jpg/1000x1000bb.jpg"),
            mediaCard(id: "channel", title: "channel ORANGE", subtitle: "Frank Ocean",
                      artwork: "https://is5-ssl.mzstatic.com/image/thumb/Music115/v4/ab/2c/71/ab2c71d4-3a55-9e3c-1bc1-f5b9f6a5c77d/00602537156010.rgb.jpg/1000x1000bb.jpg")
        ]
    }
    private func demoAlbums_recommended() -> [MediaCard] {
        return [
            mediaCard(id: "flylo", title: "Cosmogramma", subtitle: "Flying Lotus",
                      artwork: "https://is4-ssl.mzstatic.com/image/thumb/Music115/v4/6a/8e/4a/6a8e4a2c-57c4-0c9a-1c2c-5612e2f4e8d7/5051083060971.jpg/1000x1000bb.jpg"),
            mediaCard(id: "ross", title: "A Color Map of the Sun", subtitle: "Pretty Lights",
                      artwork: "https://is3-ssl.mzstatic.com/image/thumb/Music/v4/2d/7a/a3/2d7aa3a8-3a4f-1a2e-0f95-5b7d9f39c103/Pretty_Lights-ACMOTS.jpg/1000x1000bb.jpg"),
            mediaCard(id: "ojal", title: "Ojai", subtitle: "Tycho",
                      artwork: "https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/1c/5d/d3/1c5dd373-4a5b-3ae8-9fd5-1f5e84e4a01c/tych%20-%20oi.jpg/1000x1000bb.jpg")
        ]
    }
    private func demoAlbums_charts() -> [MediaCard] {
        return [
            mediaCard(id: "tortured", title: "THE TORTURED POETS DEPARTMENT", subtitle: "Taylor Swift",
                      artwork: "https://is2-ssl.mzstatic.com/image/thumb/Music126/v4/29/1e/f7/291ef78e-8776-8ee3-0bc9-1a9befb5f675/24UM1IM23004.rgb.jpg/1000x1000bb.jpg"),
            mediaCard(id: "cowboy", title: "COWBOY CARTER", subtitle: "Beyoncé",
                      artwork: "https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/9b/1b/4a/9b1b4a7c-6a1b-b5c3-0f14-6b23f8e5e1a8/196871671034.jpg/1000x1000bb.jpg"),
            mediaCard(id: "bruno", title: "24K Magic", subtitle: "Bruno Mars",
                      artwork: "https://is4-ssl.mzstatic.com/image/thumb/Music118/v4/92/ea/6d/92ea6d23-3b0f-a2cf-6d75-1703f8f4ef06/075679914614.jpg/1000x1000bb.jpg")
        ]
    }
    private func demoAlbums_genres() -> [MediaCard] {
        return [
            mediaCard(id: "jazz", title: "Kind of Blue", subtitle: "Miles Davis",
                      artwork: "https://is4-ssl.mzstatic.com/image/thumb/Music128/v4/44/00/40/44004092-3e2c-662c-2f2a-3e46d39be2a4/190295851514.jpg/1000x1000bb.jpg"),
            mediaCard(id: "rock", title: "The Dark Side of the Moon", subtitle: "Pink Floyd",
                      artwork: "https://is5-ssl.mzstatic.com/image/thumb/Music126/v4/50/ea/9e/50ea9e72-6422-1a39-ff43-38421c87635e/12UMGIM09536.rgb.jpg/1000x1000bb.jpg"),
            mediaCard(id: "electronic", title: "Discovery", subtitle: "Daft Punk",
                      artwork: "https://is3-ssl.mzstatic.com/image/thumb/Music125/v4/e9/27/c0/e927c0b8-ea3b-2a5f-0c9b-a1407e3f2354/190295851972.jpg/1000x1000bb.jpg")
        ]
    }
    private func demoPlaylists_curated() -> [MediaCard] {
        return [
            mediaCard(id: "chill", title: "Chill Mix", subtitle: "Apple Music", artwork: "https://is3-ssl.mzstatic.com/image/thumb/Features116/v4/8a/d0/d5/8ad0d5a1-1c77-0e8d-6b9b-2d0c9fa1f9c5/dj.rjclllcc.jpg/1000x1000bb.jpg"),
            mediaCard(id: "newmusic", title: "New Music Mix", subtitle: "Apple Music", artwork: "https://is5-ssl.mzstatic.com/image/thumb/Features126/v4/3a/9b/1d/3a9b1da9-7d18-85f4-5447-d4c7df25b4b0/dj.auxqqqqw.jpg/1000x1000bb.jpg"),
            mediaCard(id: "dance", title: "Dance XL", subtitle: "Apple Music Dance", artwork: "https://is4-ssl.mzstatic.com/image/thumb/Features126/v4/20/b9/7a/20b97a5a-ec7b-9ac6-3deb-b9bca0cf9b63/dj.zpllslsm.jpg/1000x1000bb.jpg")
        ]
    }
    #else
    func requestAuthorizationIfNeeded() async throws {
        let status = MusicAuthorization.currentStatus
        if status == .notDetermined {
            let newStatus = await MusicAuthorization.request()
            guard newStatus == .authorized else { throw NSError(domain: "MusicAuth", code: 1) }
        }
    }

    func currentNowPlaying() async -> NowPlayingItem? {
        let player = SystemMusicPlayer.shared
        guard let entry = player.queue.currentEntry else { return nil }
        let title = entry.title
        let artist = entry.subtitle ?? ""
        // Album and year are not guaranteed from Queue.Entry; leave album empty and year nil for now
        return NowPlayingItem(title: title, artistName: artist, albumName: "", releaseYear: nil)
    }

    func currentEditorialNote() async -> EditorialNote? {
        // MusicKit SDK does not directly expose editorial notes for now playing; return nil for now.
        return nil
    }
    func listenNowSections() async -> [SectionOfCards] { return [] }
    func browseSections() async -> [SectionOfCards] { return [] }
    #endif
}

#else
final class AppleMusicService: AppleMusicServiceProtocol {
    func requestAuthorizationIfNeeded() async throws {}
    func currentNowPlaying() async -> NowPlayingItem? { nil }
    func currentEditorialNote() async -> EditorialNote? { nil }
}
#endif


