import Foundation

enum FactSubject: String, Codable, CaseIterable {
    case artist
    case album
}

struct Fact: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let subject: FactSubject
    let source: String?

    init(id: UUID = UUID(), text: String, subject: FactSubject, source: String? = nil) {
        self.id = id
        self.text = text
        self.subject = subject
        self.source = source
    }
}

