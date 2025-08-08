import Foundation

#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig

final class RemoteConfigService: ObservableObject {
    static let shared = RemoteConfigService()

    @Published private(set) var values: RemoteConfigValues = .defaults

    private let remoteConfig: RemoteConfig

    private init() {
        self.remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults(fromPlist: "RemoteConfigDefaults")
    }

    func fetchAndActivate() async {
        do {
            let status = try await remoteConfig.fetchAndActivate()
            if status == .successFetchedFromRemote || status == .successUsingPreFetchedData {
                self.values = decodeValues()
            }
        } catch {
            // Keep defaults on error
        }
    }

    private func decodeValues() -> RemoteConfigValues {
        let json: [String: Any] = [
            "initialBatch": remoteConfig["initialBatch"].numberValue.intValue,
            "topUpBatch": remoteConfig["topUpBatch"].numberValue.intValue,
            "prefetchThreshold": remoteConfig["prefetchThreshold"].numberValue.intValue,
            "factMinIntervalSec": remoteConfig["factMinIntervalSec"].numberValue.intValue,
            "factMaxIntervalSec": remoteConfig["factMaxIntervalSec"].numberValue.intValue,
            "chipMinIntervalSec": remoteConfig["chipMinIntervalSec"].numberValue.intValue,
            "chipMaxIntervalSec": remoteConfig["chipMaxIntervalSec"].numberValue.intValue,
            "chipDwellSec": remoteConfig["chipDwellSec"].numberValue.intValue,
            "enableEditorial": remoteConfig["enableEditorial"].boolValue,
            "colorIntensity": remoteConfig["colorIntensity"].stringValue ?? RemoteConfigValues.defaults.colorIntensity,
            "defaultMode": remoteConfig["defaultMode"].stringValue ?? RemoteConfigValues.defaults.defaultMode
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            return try JSONDecoder().decode(RemoteConfigValues.self, from: data)
        } catch {
            return .defaults
        }
    }
}
#else
final class RemoteConfigService: ObservableObject {
    static let shared = RemoteConfigService()
    @Published private(set) var values: RemoteConfigValues = .defaults
    private init() {}
    func fetchAndActivate() async { /* no-op on unsupported platform */ }
}
#endif

