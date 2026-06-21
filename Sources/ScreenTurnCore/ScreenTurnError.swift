import Foundation

public enum ScreenTurnError: LocalizedError, Equatable {
    case displayPlacerNotFound
    case displayPlacerFailed(command: String, status: Int32, output: String)
    case noDisplaysFound
    case targetDisplayNotConfigured
    case targetDisplayNotFound(String)
    case noSavedDisplayState
    case unsupportedHotKey(String)
    case invalidConfig(String)

    public var errorDescription: String? {
        switch self {
        case .displayPlacerNotFound:
            return "displayplacer was not found. Install it with: brew install displayplacer"
        case let .displayPlacerFailed(command, status, output):
            return "displayplacer failed while running '\(command)' with exit code \(status).\n\(output)"
        case .noDisplaysFound:
            return "No displays were found in displayplacer output."
        case .targetDisplayNotConfigured:
            return "No display ID is configured. Run setup or edit the ScreenTurn config."
        case let .targetDisplayNotFound(displayID):
            return "Configured display was not found: \(displayID)"
        case .noSavedDisplayState:
            return "No previous display state is available to restore."
        case let .unsupportedHotKey(key):
            return "Unsupported hotkey key: \(key)"
        case let .invalidConfig(message):
            return "Invalid ScreenTurn config: \(message)"
        }
    }
}
