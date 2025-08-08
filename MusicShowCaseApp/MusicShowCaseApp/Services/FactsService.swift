import Foundation

#if canImport(FirebaseFunctions)
import FirebaseFunctions

protocol FactsServiceProtocol {
    func fetchFacts(artistName: String, albumName: String, releaseYear: Int, max: Int) async throws -> [Fact]
}

final class FactsService: FactsServiceProtocol {
    private lazy var functions = Functions.functions()

    func fetchFacts(artistName: String, albumName: String, releaseYear: Int, max: Int) async throws -> [Fact] {
        let data: [String: Any] = [
            "artist_name": artistName,
            "album_name": albumName,
            "release_year": releaseYear,
            "max": max
        ]

        let result = try await functions.httpsCallable("generateFacts").call(data)
        guard let dict = result.data as? [String: Any],
              let items = dict["facts"] as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item in
            guard let text = item["text"] as? String,
                  let subjectRaw = item["subject"] as? String,
                  let subject = FactSubject(rawValue: subjectRaw) else { return nil }
            let source = item["source"] as? String
            return Fact(text: text, subject: subject, source: source)
        }
    }
}
@available(*, unavailable)
extension FactsService: @unchecked Sendable {}

#else
final class FactsService: FactsServiceProtocol {
    func fetchFacts(artistName: String, albumName: String, releaseYear: Int, max: Int) async throws -> [Fact] {
        return []
    }
}
#endif

