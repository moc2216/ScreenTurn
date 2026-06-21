import Foundation

public struct ScreenTurnConfig: Codable, Equatable {
    public var displayID: String
    public var landscapeResolution: String
    public var portraitResolution: String
    public var landscapeDegree: Int
    public var portraitDegree: Int
    public var hertz: Int
    public var colorDepth: Int
    public var scaling: String
    public var origin: String
    public var hotKey: HotKeyConfig
    public var lastKnownDisplayState: SavedDisplayState?

    public init(
        displayID: String,
        landscapeResolution: String,
        portraitResolution: String,
        landscapeDegree: Int,
        portraitDegree: Int,
        hertz: Int,
        colorDepth: Int,
        scaling: String,
        origin: String,
        hotKey: HotKeyConfig,
        lastKnownDisplayState: SavedDisplayState? = nil
    ) {
        self.displayID = displayID
        self.landscapeResolution = landscapeResolution
        self.portraitResolution = portraitResolution
        self.landscapeDegree = landscapeDegree
        self.portraitDegree = portraitDegree
        self.hertz = hertz
        self.colorDepth = colorDepth
        self.scaling = scaling
        self.origin = origin
        self.hotKey = hotKey
        self.lastKnownDisplayState = lastKnownDisplayState
    }

    public static let `default` = ScreenTurnConfig(
        displayID: "",
        landscapeResolution: "1920x1080",
        portraitResolution: "1080x1920",
        landscapeDegree: 0,
        portraitDegree: 270,
        hertz: 60,
        colorDepth: 8,
        scaling: "on",
        origin: "(0,0)",
        hotKey: .default
    )

    public func validateForToggle() throws {
        try hotKey.validate()
        guard !displayID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ScreenTurnError.targetDisplayNotConfigured
        }
        guard !landscapeResolution.isEmpty, !portraitResolution.isEmpty else {
            throw ScreenTurnError.invalidConfig("landscapeResolution and portraitResolution are required.")
        }
    }
}
