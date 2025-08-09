import Foundation

final class ArtworkService {
    static let shared = ArtworkService()

    private let cache = NSCache<NSString, NSData>()
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = true
        config.allowsConstrainedNetworkAccess = true
        config.networkServiceType = .responsiveData
        config.httpAdditionalHeaders = [
            "User-Agent": "MusicShowCase/1.0 (tvOS)"
        ]
        return URLSession(configuration: config)
    }()

    private init() {}

    func fetchArtworkData(artistName: String, albumName: String?, title: String?) async -> Data? {
        let queryKey = cacheKey(artist: artistName, album: albumName, title: title)
        if let cached = cache.object(forKey: queryKey as NSString) {
            return cached as Data
        }

        guard let searchURL = makeSearchURL(artist: artistName, album: albumName, title: title) else { return nil }
        #if DEBUG
        print("[Artwork] search URL: \(searchURL.absoluteString)")
        #endif
        do {
            // Album-first
            if let url = try await searchArtworkURL(url: searchURL) {
                #if DEBUG
                print("[Artwork] found artwork: \(url.absoluteString)")
                #endif
                let (imageData, _) = try await session.data(from: url)
                cache.setObject(imageData as NSData, forKey: queryKey as NSString)
                return imageData
            }
            // Fallback: alternate search (e.g., song)
            if let altURL = alternateSearchURL(artist: artistName, album: albumName, title: title),
               let found = try await searchArtworkURL(url: altURL) {
                #if DEBUG
                print("[Artwork] fallback found: \(found.absoluteString)")
                #endif
                let (imageData, _) = try await session.data(from: found)
                cache.setObject(imageData as NSData, forKey: queryKey as NSString)
                return imageData
            }
            // As a last resort, try a direct 600x600 size from original JSON
            let (data, _) = try await session.data(from: searchURL)
            guard let url = extractArtworkURL(from: data, targetSize: 600) else { return nil }
            #if DEBUG
            print("[Artwork] last-resort URL: \(url.absoluteString)")
            #endif
            let (imageData, _) = try await session.data(from: url)
            cache.setObject(imageData as NSData, forKey: queryKey as NSString)
            return imageData
        } catch {
            #if DEBUG
            print("[Artwork] failed: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    private func cacheKey(artist: String, album: String?, title: String?) -> String {
        [artist.lowercased(), album?.lowercased() ?? "", title?.lowercased() ?? ""].joined(separator: "|")
    }

    private func makeSearchURL(artist: String, album: String?, title: String?) -> URL? {
        var termComponents: [String] = [artist]
        if let album, !album.isEmpty { termComponents.append(album) }
        if let title, !title.isEmpty { termComponents.append(title) }
        let term = termComponents.joined(separator: " ")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let entity = (album != nil && !(album?.isEmpty ?? true)) ? "album" : "song"
        let urlString = "https://itunes.apple.com/search?term=\(term)&media=music&entity=\(entity)&country=US&limit=1"
        return URL(string: urlString)
    }

    private func alternateSearchURL(artist: String, album: String?, title: String?) -> URL? {
        // Swap entity: if album search failed, try song; if song failed, try album
        var termComponents: [String] = [artist]
        if let album, !album.isEmpty { termComponents.append(album) }
        if let title, !title.isEmpty { termComponents.append(title) }
        let term = termComponents.joined(separator: " ")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://itunes.apple.com/search?term=\(term)&media=music&entity=song&country=US&limit=1"
        return URL(string: urlString)
    }

    private func searchArtworkURL(url: URL) async throws -> URL? {
        let (data, _) = try await session.data(from: url)
        // Try higher sizes first, then fall back
        for size in [2000, 1500, 1200, 1000] {
            if let url = extractArtworkURL(from: data, targetSize: size) {
                return url
            }
        }
        return extractArtworkURL(from: data, targetSize: 1000)
    }

    private func extractArtworkURL(from data: Data, targetSize: Int) -> URL? {
        struct SearchResponse: Decodable { let results: [Result] }
        struct Result: Decodable { let artworkUrl100: String? }
        guard let response = try? JSONDecoder().decode(SearchResponse.self, from: data),
              let raw = response.results.first?.artworkUrl100 else { return nil }
        let upscaled = raw
            .replacingOccurrences(of: "/100x100bb", with: "/\(targetSize)x\(targetSize)bb")
            .replacingOccurrences(of: "/100x100", with: "/\(targetSize)x\(targetSize)")
            .replacingOccurrences(of: "http://", with: "https://")
        return URL(string: upscaled)
    }

    // Fetch multiple candidate artworks (album/song) and return their image data
    func fetchArtworkCandidates(artistName: String, albumName: String?, title: String?, max: Int = 4) async -> [Data] {
        var candidates: [Data] = []
        // Build a broader search (limit up to max*2 to increase diversity)
        var termComponents: [String] = [artistName]
        if let albumName, !albumName.isEmpty { termComponents.append(albumName) }
        if let title, !title.isEmpty { termComponents.append(title) }
        let term = termComponents.joined(separator: " ")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Try album first then song, with higher limits
        let urls: [URL] = [
            URL(string: "https://itunes.apple.com/search?term=\(term)&media=music&entity=album&country=US&limit=\(max*2)")!,
            URL(string: "https://itunes.apple.com/search?term=\(term)&media=music&entity=song&country=US&limit=\(max*2)")!
        ]
        do {
            for url in urls {
                let (data, _) = try await session.data(from: url)
                struct SearchResponse: Decodable { let results: [Result] }
                struct Result: Decodable { let artworkUrl100: String? }
                guard let response = try? JSONDecoder().decode(SearchResponse.self, from: data) else { continue }
                for res in response.results {
                    guard let raw = res.artworkUrl100 else { continue }
                    let up = raw
                        .replacingOccurrences(of: "/100x100bb", with: "/1000x1000bb")
                        .replacingOccurrences(of: "/100x100", with: "/1000x1000")
                        .replacingOccurrences(of: "http://", with: "https://")
                    let key = up as NSString
                    if let cached = cache.object(forKey: key) {
                        candidates.append(cached as Data)
                    } else if let u = URL(string: up) {
                        do {
                            let (img, _) = try await session.data(from: u)
                            cache.setObject(img as NSData, forKey: key)
                            candidates.append(img)
                        } catch { continue }
                    }
                    if candidates.count >= max { return candidates }
                }
            }
        } catch { }
        return candidates
    }
}

extension ArtworkService {
    func fetchDirect(url: URL) async throws -> Data {
        let (data, _) = try await session.data(from: url)
        return data
    }
}


