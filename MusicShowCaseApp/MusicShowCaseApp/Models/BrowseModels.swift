import Foundation

struct MediaCard: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let artworkURL: String?
}

struct SectionOfCards: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [MediaCard]
}


