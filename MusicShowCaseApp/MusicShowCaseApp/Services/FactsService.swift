import Foundation

#if canImport(FirebaseFunctions)
import FirebaseFunctions

protocol FactsServiceProtocol {
    func fetchFacts(artistName: String, albumName: String, releaseYear: Int, max: Int) async throws -> [Fact]
}

final class FactsService: FactsServiceProtocol {
    private lazy var functions = Functions.functions()

    func fetchFacts(artistName: String, albumName: String, releaseYear: Int, max: Int) async throws -> [Fact] {
        do {
            let data: [String: Any] = [
                "artist_name": artistName,
                "album_name": albumName,
                "release_year": releaseYear,
                "max": max
            ]

            let result = try await functions.httpsCallable("generateFacts").call(data)
            guard let dict = result.data as? [String: Any],
                  let items = dict["facts"] as? [[String: Any]] else {
                return mockFacts(artistName: artistName, albumName: albumName, releaseYear: releaseYear, max: max)
            }

            let parsed = items.compactMap { item -> Fact? in
                guard let text = item["text"] as? String,
                      let subjectRaw = item["subject"] as? String,
                      let subject = FactSubject(rawValue: subjectRaw) else { return nil }
                let source = item["source"] as? String
                return Fact(text: text, subject: subject, source: source)
            }
            return parsed.isEmpty ? mockFacts(artistName: artistName, albumName: albumName, releaseYear: releaseYear, max: max) : parsed
        } catch {
            return mockFacts(artistName: artistName, albumName: albumName, releaseYear: releaseYear, max: max)
        }
    }

    private func mockFacts(artistName: String, albumName: String, releaseYear: Int, max: Int) -> [Fact] {
        let base: [String] = [
            "\(artistName) released \(albumName) in \(releaseYear).",
            "The album \(albumName) blends electronic textures with live instrumentation.",
            "\(artistName) drew inspiration from 70s/80s studio techniques on \(albumName).",
            "Fun tidbit: \(albumName) features multiple collaborators across genres.",
            "Fans often cite \(albumName) as a late-night headphone record.",
            "A standout track on \(albumName) showcases lush analog synths.",
            "\(artistName)'s production style emphasizes groove and atmosphere.",
            "The sequencing of \(albumName) encourages front-to-back listening."
        ]
        return (0..<max).map { idx in
            let text = base[idx % base.count]
            let subject: FactSubject = (idx % 2 == 0) ? .artist : .album
            return Fact(text: text, subject: subject, source: "demo")
        }
    }
}
@available(*, unavailable)
extension FactsService: @unchecked Sendable {}

#else
protocol FactsServiceProtocol {
    func fetchFacts(artistName: String, albumName: String, releaseYear: Int, max: Int) async throws -> [Fact]
}

final class FactsService: FactsServiceProtocol {
    func fetchFacts(artistName: String, albumName: String, releaseYear: Int, max: Int) async throws -> [Fact] {
        let base: [String] = [
            "\(artistName) released \(albumName) in \(releaseYear).",
            "The album \(albumName) blends electronic textures with live instrumentation.",
            "\(artistName) drew inspiration from 70s/80s studio techniques on \(albumName).",
            "Fun tidbit: \(albumName) features multiple collaborators across genres.",
            "Fans often cite \(albumName) as a late-night headphone record.",
            "A standout track on \(albumName) showcases lush analog synths.",
            "\(artistName)'s production style emphasizes groove and atmosphere.",
            "The sequencing of \(albumName) encourages front-to-back listening."
        ]
        return (0..<max).map { idx in
            let text = base[idx % base.count]
            let subject: FactSubject = (idx % 2 == 0) ? .artist : .album
            return Fact(text: text, subject: subject, source: "demo")
        }
    }
}
#endif

