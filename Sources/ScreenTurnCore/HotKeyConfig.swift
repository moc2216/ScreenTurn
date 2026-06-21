import Foundation

public enum HotKeyModifier: String, Codable, CaseIterable, Equatable {
    case control
    case option
    case shift
    case command

    public var symbol: String {
        switch self {
        case .control:
            return "⌃"
        case .option:
            return "⌥"
        case .shift:
            return "⇧"
        case .command:
            return "⌘"
        }
    }
}

public struct HotKeyConfig: Codable, Equatable {
    public var key: String
    public var modifiers: [HotKeyModifier]

    public init(key: String, modifiers: [HotKeyModifier]) {
        self.key = key
        self.modifiers = modifiers
    }

    public static let `default` = HotKeyConfig(
        key: "R",
        modifiers: [.control, .option, .command]
    )

    public var normalizedKey: String {
        key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    public var displayString: String {
        let order: [HotKeyModifier] = [.control, .option, .shift, .command]
        let modifierSymbols = order
            .filter { modifiers.contains($0) }
            .map(\.symbol)
            .joined()
        return modifierSymbols + normalizedKey
    }

    public var keyCode: UInt32? {
        KeyCodeCatalog.keyCodes[normalizedKey]
    }

    public func validate() throws {
        if keyCode == nil {
            throw ScreenTurnError.unsupportedHotKey(key)
        }
        if modifiers.isEmpty {
            throw ScreenTurnError.invalidConfig("hotKey.modifiers must contain at least one modifier.")
        }
    }
}

public enum KeyCodeCatalog {
    public static let keyCodes: [String: UInt32] = [
        "A": 0x00,
        "S": 0x01,
        "D": 0x02,
        "F": 0x03,
        "H": 0x04,
        "G": 0x05,
        "Z": 0x06,
        "X": 0x07,
        "C": 0x08,
        "V": 0x09,
        "B": 0x0B,
        "Q": 0x0C,
        "W": 0x0D,
        "E": 0x0E,
        "R": 0x0F,
        "Y": 0x10,
        "T": 0x11,
        "1": 0x12,
        "2": 0x13,
        "3": 0x14,
        "4": 0x15,
        "6": 0x16,
        "5": 0x17,
        "=": 0x18,
        "9": 0x19,
        "7": 0x1A,
        "-": 0x1B,
        "8": 0x1C,
        "0": 0x1D,
        "]": 0x1E,
        "O": 0x1F,
        "U": 0x20,
        "[": 0x21,
        "I": 0x22,
        "P": 0x23,
        "L": 0x25,
        "J": 0x26,
        "'": 0x27,
        "K": 0x28,
        ";": 0x29,
        "\\": 0x2A,
        ",": 0x2B,
        "/": 0x2C,
        "N": 0x2D,
        "M": 0x2E,
        ".": 0x2F,
        "`": 0x32,
        "SPACE": 0x31,
        "TAB": 0x30,
        "RETURN": 0x24,
        "ENTER": 0x24,
        "ESCAPE": 0x35,
        "ESC": 0x35,
        "DELETE": 0x33,
        "BACKSPACE": 0x33,
        "LEFT": 0x7B,
        "RIGHT": 0x7C,
        "DOWN": 0x7D,
        "UP": 0x7E,
        "F1": 0x7A,
        "F2": 0x78,
        "F3": 0x63,
        "F4": 0x76,
        "F5": 0x60,
        "F6": 0x61,
        "F7": 0x62,
        "F8": 0x64,
        "F9": 0x65,
        "F10": 0x6D,
        "F11": 0x67,
        "F12": 0x6F,
        "F13": 0x69,
        "F14": 0x6B,
        "F15": 0x71,
        "F16": 0x6A,
        "F17": 0x40,
        "F18": 0x4F,
        "F19": 0x50,
        "F20": 0x5A
    ]

    public static func key(for keyCode: UInt32) -> String? {
        let preferredNames: [UInt32: String] = [
            0x24: "RETURN",
            0x31: "SPACE",
            0x33: "DELETE",
            0x35: "ESCAPE"
        ]

        if let preferredName = preferredNames[keyCode] {
            return preferredName
        }

        return keyCodes
            .filter { $0.value == keyCode }
            .map(\.key)
            .sorted()
            .first
    }
}
