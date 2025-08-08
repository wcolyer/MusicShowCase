import Foundation

struct RemoteConfigValues: Codable, Equatable {
    let initialBatch: Int
    let topUpBatch: Int
    let prefetchThreshold: Int
    let factMinIntervalSec: Int
    let factMaxIntervalSec: Int
    let chipMinIntervalSec: Int
    let chipMaxIntervalSec: Int
    let chipDwellSec: Int
    let enableEditorial: Bool
    let colorIntensity: String
    let defaultMode: String

    static let defaults = RemoteConfigValues(
        initialBatch: 10,
        topUpBatch: 8,
        prefetchThreshold: 3,
        factMinIntervalSec: 18,
        factMaxIntervalSec: 35,
        chipMinIntervalSec: 45,
        chipMaxIntervalSec: 70,
        chipDwellSec: 10,
        enableEditorial: true,
        colorIntensity: "standard",
        defaultMode: "wall"
    )
}

