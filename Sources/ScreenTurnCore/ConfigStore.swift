import Foundation

public final class ConfigStore {
    public let appSupportDirectory: URL
    public let configURL: URL

    public init(fileManager: FileManager = .default) {
        if let override = ProcessInfo.processInfo.environment["SCREENTURN_CONFIG_DIR"],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            appSupportDirectory = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
            appSupportDirectory = baseURL.appendingPathComponent("ScreenTurn", isDirectory: true)
        }
        configURL = appSupportDirectory.appendingPathComponent("config.json")
    }

    public func load() throws -> ScreenTurnConfig {
        let data = try Data(contentsOf: configURL)
        let decoder = JSONDecoder()
        return try decoder.decode(ScreenTurnConfig.self, from: data)
    }

    public func loadOrCreateDefault() throws -> ScreenTurnConfig {
        if FileManager.default.fileExists(atPath: configURL.path) {
            return try load()
        }

        let config = ScreenTurnConfig.default
        try save(config)
        return config
    }

    public func save(_ config: ScreenTurnConfig) throws {
        try FileManager.default.createDirectory(
            at: appSupportDirectory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: .atomic)
    }
}
