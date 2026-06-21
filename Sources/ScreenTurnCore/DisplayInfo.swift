import Foundation

public struct DisplayInfo: Equatable {
    public var persistentID: String
    public var contextualID: String?
    public var serialID: String?
    public var type: String?
    public var resolution: String?
    public var hertz: Int?
    public var colorDepth: Int?
    public var scaling: String?
    public var origin: String?
    public var rotation: Int?
    public var isMain: Bool

    public init(
        persistentID: String,
        contextualID: String? = nil,
        serialID: String? = nil,
        type: String? = nil,
        resolution: String? = nil,
        hertz: Int? = nil,
        colorDepth: Int? = nil,
        scaling: String? = nil,
        origin: String? = nil,
        rotation: Int? = nil,
        isMain: Bool = false
    ) {
        self.persistentID = persistentID
        self.contextualID = contextualID
        self.serialID = serialID
        self.type = type
        self.resolution = resolution
        self.hertz = hertz
        self.colorDepth = colorDepth
        self.scaling = scaling
        self.origin = origin
        self.rotation = rotation
        self.isMain = isMain
    }

    public func matches(_ id: String) -> Bool {
        let normalized = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return false
        }

        return persistentID == normalized
            || contextualID == normalized
            || serialID == normalized
    }
}

public enum DisplayPlacerListParser {
    public static func parse(_ output: String) -> [DisplayInfo] {
        var displays: [DisplayInfo] = []
        var current: DisplayInfo?

        func finishCurrent() {
            if let current {
                displays.append(current)
            }
            current = nil
        }

        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else {
                continue
            }

            if let value = value(after: "Persistent screen id:", in: line) {
                finishCurrent()
                current = DisplayInfo(persistentID: value)
                continue
            }

            guard current != nil else {
                continue
            }

            if let value = value(after: "Contextual screen id:", in: line) {
                current?.contextualID = value
            } else if let value = value(after: "Serial screen id:", in: line) {
                current?.serialID = value
            } else if let value = value(after: "Type:", in: line) {
                current?.type = value
            } else if let value = value(after: "Resolution:", in: line) {
                current?.resolution = firstToken(in: value)
            } else if let value = value(after: "Hertz:", in: line) {
                current?.hertz = Int(firstToken(in: value))
            } else if let value = value(after: "Color Depth:", in: line) {
                current?.colorDepth = Int(firstToken(in: value))
            } else if let value = value(after: "Scaling:", in: line) {
                current?.scaling = firstToken(in: value)
            } else if let value = value(after: "Origin:", in: line) {
                current?.origin = originValue(from: value)
                current?.isMain = value.localizedCaseInsensitiveContains("main display")
            } else if let value = value(after: "Rotation:", in: line) {
                current?.rotation = Int(firstToken(in: value))
            }
        }

        finishCurrent()
        return displays
    }

    private static func value(after prefix: String, in line: String) -> String? {
        guard line.hasPrefix(prefix) else {
            return nil
        }
        return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstToken(in value: String) -> String {
        value.split(separator: " ").first.map(String.init) ?? value
    }

    private static func originValue(from value: String) -> String {
        if let first = value.split(separator: " ").first {
            return String(first)
        }
        return value
    }
}
