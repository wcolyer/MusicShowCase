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
}

extension ArtworkService {
    func fetchDirect(url: URL) async throws -> Data {
        let (data, _) = try await session.data(from: url)
        return data
    }
}


