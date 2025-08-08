import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

protocol AnalyticsServiceProtocol {
    func log(event name: String, parameters: [String: Any])
}

final class AnalyticsService: AnalyticsServiceProtocol {
    static let shared = AnalyticsService()
    private init() {}

    func log(event name: String, parameters: [String: Any]) {
        #if canImport(FirebaseAnalytics)
        let converted: [String: Any] = parameters.mapValues { value in
            if let num = value as? NSNumber { return num }
            if let str = value as? String { return str }
            return String(describing: value)
        }
        Analytics.logEvent(name, parameters: converted)
        #else
        // no-op on unsupported platform
        #endif
    }
}

