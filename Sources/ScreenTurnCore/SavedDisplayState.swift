import Foundation

public struct SavedDisplayState: Codable, Equatable {
    public var resolution: String
    public var degree: Int
    public var hertz: Int
    public var colorDepth: Int
    public var scaling: String
    public var origin: String

    public init(
        resolution: String,
        degree: Int,
        hertz: Int,
        colorDepth: Int,
        scaling: String,
        origin: String
    ) {
        self.resolution = resolution
        self.degree = degree
        self.hertz = hertz
        self.colorDepth = colorDepth
        self.scaling = scaling
        self.origin = origin
    }
}
