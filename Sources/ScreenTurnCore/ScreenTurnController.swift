import Foundation

public struct ToggleResult: Equatable {
    public var displayID: String
    public var fromDegree: Int?
    public var toDegree: Int
    public var resolution: String
    public var command: String
    public var previousState: SavedDisplayState
}

public struct RestoreResult: Equatable {
    public var displayID: String
    public var degree: Int
    public var resolution: String
    public var command: String
}

public struct ScreenTurnStatus: Equatable {
    public var config: ScreenTurnConfig
    public var displays: [DisplayInfo]
    public var displayPlacerPath: String?
    public var displayPlacerError: String?

    public var configuredDisplay: DisplayInfo? {
        displays.first { $0.persistentID == config.displayID }
    }
}

public final class ScreenTurnController {
    public let configStore: ConfigStore

    public init(configStore: ConfigStore = ConfigStore()) {
        self.configStore = configStore
    }

    @discardableResult
    public func toggle() throws -> ToggleResult {
        let result = try planToggle()
        try saveLastKnownDisplayState(result.previousState)
        try DisplayPlacer.locate().apply(result.command)
        return result
    }

    public func planToggle() throws -> ToggleResult {
        let config = try configStore.loadOrCreateDefault()
        try config.validateForToggle()

        let displayPlacer = try DisplayPlacer.locate()
        let displays = try displayPlacer.listDisplays()
        guard !displays.isEmpty else {
            throw ScreenTurnError.noDisplaysFound
        }

        guard let targetDisplay = displays.first(where: { $0.persistentID == config.displayID }) else {
            throw ScreenTurnError.targetDisplayNotFound(config.displayID)
        }

        let currentDegree = targetDisplay.rotation ?? config.landscapeDegree
        let isLandscape = currentDegree == config.landscapeDegree
        let toDegree = isLandscape ? config.portraitDegree : config.landscapeDegree
        let resolution = isLandscape ? config.portraitResolution : config.landscapeResolution
        let previousResolution = targetDisplay.resolution
            ?? (isLandscape ? config.landscapeResolution : config.portraitResolution)
        let previousState = SavedDisplayState(
            resolution: previousResolution,
            degree: currentDegree,
            hertz: targetDisplay.hertz ?? config.hertz,
            colorDepth: targetDisplay.colorDepth ?? config.colorDepth,
            scaling: targetDisplay.scaling ?? config.scaling,
            origin: targetDisplay.origin ?? config.origin
        )
        let command = Self.command(
            displayID: config.displayID,
            resolution: resolution,
            hertz: config.hertz,
            colorDepth: config.colorDepth,
            scaling: config.scaling,
            origin: config.origin,
            degree: toDegree
        )

        return ToggleResult(
            displayID: config.displayID,
            fromDegree: currentDegree,
            toDegree: toDegree,
            resolution: resolution,
            command: command,
            previousState: previousState
        )
    }

    @discardableResult
    public func restoreLastKnownDisplayState() throws -> RestoreResult {
        let result = try planRestoreLastKnownDisplayState()
        try DisplayPlacer.locate().apply(result.command)

        var config = try configStore.loadOrCreateDefault()
        config.lastKnownDisplayState = nil
        try configStore.save(config)

        return result
    }

    public func planRestoreLastKnownDisplayState() throws -> RestoreResult {
        let config = try configStore.loadOrCreateDefault()
        try config.validateForToggle()

        guard let state = config.lastKnownDisplayState else {
            throw ScreenTurnError.noSavedDisplayState
        }

        let command = Self.command(
            displayID: config.displayID,
            resolution: state.resolution,
            hertz: state.hertz,
            colorDepth: state.colorDepth,
            scaling: state.scaling,
            origin: state.origin,
            degree: state.degree
        )

        return RestoreResult(
            displayID: config.displayID,
            degree: state.degree,
            resolution: state.resolution,
            command: command
        )
    }

    @discardableResult
    public func configureFromCurrentDisplay(displayID: String? = nil) throws -> ScreenTurnConfig {
        let existing = try? configStore.loadOrCreateDefault()
        let displayPlacer = try DisplayPlacer.locate()
        let displays = try displayPlacer.listDisplays()
        guard !displays.isEmpty else {
            throw ScreenTurnError.noDisplaysFound
        }

        let selected = try selectDisplay(
            from: displays,
            requestedDisplayID: displayID,
            preferredDisplayID: existing?.displayID
        )
        let config = Self.configuredConfig(existing ?? .default, for: selected)

        try config.hotKey.validate()
        try configStore.save(config)
        return config
    }

    @discardableResult
    public func configureWithoutDetection(displayID: String) throws -> ScreenTurnConfig {
        let normalizedDisplayID = displayID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedDisplayID.isEmpty else {
            throw ScreenTurnError.targetDisplayNotConfigured
        }

        var config = try configStore.loadOrCreateDefault()
        config.displayID = normalizedDisplayID
        config.lastKnownDisplayState = nil
        try config.hotKey.validate()
        try configStore.save(config)
        return config
    }

    public func status() throws -> ScreenTurnStatus {
        let config = try configStore.loadOrCreateDefault()

        do {
            let displayPlacer = try DisplayPlacer.locate()
            let displays = try displayPlacer.listDisplays()
            return ScreenTurnStatus(
                config: config,
                displays: displays,
                displayPlacerPath: displayPlacer.executablePath,
                displayPlacerError: nil
            )
        } catch {
            return ScreenTurnStatus(
                config: config,
                displays: [],
                displayPlacerPath: nil,
                displayPlacerError: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
        }
    }

    public static func command(
        displayID: String,
        resolution: String,
        hertz: Int,
        colorDepth: Int,
        scaling: String,
        origin: String,
        degree: Int
    ) -> String {
        "id:\(displayID) res:\(resolution) hz:\(hertz) color_depth:\(colorDepth) enabled:true scaling:\(scaling) origin:\(origin) degree:\(degree)"
    }

    public static func inferResolutions(from resolution: String) -> (landscape: String, portrait: String)? {
        let parts = resolution.lowercased().split(separator: "x")
        guard parts.count == 2,
              let width = Int(parts[0]),
              let height = Int(parts[1]) else {
            return nil
        }

        if width >= height {
            return ("\(width)x\(height)", "\(height)x\(width)")
        }
        return ("\(height)x\(width)", "\(width)x\(height)")
    }

    public static func configuredConfig(
        _ existing: ScreenTurnConfig,
        for display: DisplayInfo
    ) -> ScreenTurnConfig {
        var config = existing
        config.displayID = display.persistentID

        if let resolution = display.resolution,
           let inferred = inferResolutions(from: resolution) {
            config.landscapeResolution = inferred.landscape
            config.portraitResolution = inferred.portrait
        }

        config.hertz = display.hertz ?? config.hertz
        config.colorDepth = display.colorDepth ?? config.colorDepth
        config.scaling = display.scaling ?? config.scaling
        config.origin = display.origin ?? config.origin
        config.landscapeDegree = 0
        config.lastKnownDisplayState = nil

        if let rotation = display.rotation, rotation != 0 {
            config.portraitDegree = rotation
        } else if config.portraitDegree == config.landscapeDegree {
            config.portraitDegree = 270
        }

        return config
    }

    private func saveLastKnownDisplayState(_ state: SavedDisplayState) throws {
        var config = try configStore.loadOrCreateDefault()
        config.lastKnownDisplayState = state
        try configStore.save(config)
    }

    private func selectDisplay(
        from displays: [DisplayInfo],
        requestedDisplayID: String?,
        preferredDisplayID: String?
    ) throws -> DisplayInfo {
        if let requestedDisplayID,
           !requestedDisplayID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let match = displays.first(where: { $0.matches(requestedDisplayID) }) else {
                throw ScreenTurnError.targetDisplayNotFound(requestedDisplayID)
            }
            return match
        }

        if let preferredDisplayID,
           !preferredDisplayID.isEmpty,
           let match = displays.first(where: { $0.persistentID == preferredDisplayID }) {
            return match
        }

        if let rotated = displays.first(where: { ($0.rotation ?? 0) != 0 }) {
            return rotated
        }

        if let main = displays.first(where: \.isMain) {
            return main
        }

        return displays[0]
    }
}
