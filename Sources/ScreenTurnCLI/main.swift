import Foundation
import ScreenTurnCore

struct ScreenTurnCLI {
    static let version = "0.1.1"

    let arguments: [String]
    let controller = ScreenTurnController()
    let configStore = ConfigStore()

    func run() throws {
        var parsedArguments = arguments
        let dryRun = parsedArguments.removeAllOptions(["--dry-run", "-n"])
        let command = parsedArguments.first ?? "toggle"

        switch command {
        case "toggle", "t":
            let result = dryRun ? try controller.planToggle() : try controller.toggle()
            if dryRun {
                print("Would switch \(result.displayID) to \(result.toDegree) deg at \(result.resolution)")
                print("displayplacer \"\(result.command)\"")
            } else {
                print("Switched \(result.displayID) to \(result.toDegree) deg at \(result.resolution)")
            }
        case "restore", "undo", "r":
            let result = dryRun
                ? try controller.planRestoreLastKnownDisplayState()
                : try controller.restoreLastKnownDisplayState()
            if dryRun {
                print("Would restore \(result.displayID) to \(result.degree) deg at \(result.resolution)")
                print("displayplacer \"\(result.command)\"")
            } else {
                print("Restored \(result.displayID) to \(result.degree) deg at \(result.resolution)")
            }
        case "setup", "s":
            let requestedDisplayID = parsedArguments.dropFirst().first
            let config = try controller.configureFromCurrentDisplay(displayID: requestedDisplayID)
            print("Configured display: \(config.displayID)")
            print("Landscape: \(config.landscapeDegree) deg \(config.landscapeResolution)")
            print("Portrait: \(config.portraitDegree) deg \(config.portraitResolution)")
            print("Shortcut: \(config.hotKey.displayString)")
            print("Config: \(configStore.configURL.path)")
        case "use":
            let useArguments = Array(parsedArguments.dropFirst())
            let force = useArguments.contains("--force")
            let requestedDisplayID = useArguments.first { $0 != "--force" }

            guard let requestedDisplayID else {
                throw ScreenTurnError.invalidConfig("Usage: st use [--force] <display-id>")
            }

            let config = force
                ? try controller.configureWithoutDetection(displayID: requestedDisplayID)
                : try controller.configureFromCurrentDisplay(displayID: requestedDisplayID)
            print("Configured display: \(config.displayID)")
            if force {
                print("Saved without display detection. Run st doctor when the target display is connected.")
            }
            print("Config: \(configStore.configURL.path)")
        case "status", "stat", "ls", "list":
            let status = try controller.status()
            printStatus(status)
        case "config-path", "path", "p":
            print(configStore.configURL.path)
        case "open-config", "open", "config", "edit":
            _ = try configStore.loadOrCreateDefault()
            try open(configStore.configURL)
            print("Opened \(configStore.configURL.path)")
        case "doctor", "check":
            try printDoctor()
        case "version", "--version", "-v":
            print(Self.version)
        case "help", "--help", "-h", "h":
            printHelp()
        default:
            throw ScreenTurnError.invalidConfig("Unknown command: \(command)")
        }
    }

    private func printStatus(_ status: ScreenTurnStatus) {
        print("Config: \(configStore.configURL.path)")
        print("displayplacer: \(status.displayPlacerPath ?? "not found")")
        if let displayPlacerError = status.displayPlacerError {
            print("displayplacer error: \(displayPlacerError)")
        }
        print("Display ID: \(status.config.displayID.isEmpty ? "-" : status.config.displayID)")
        print("Landscape: \(status.config.landscapeDegree) deg \(status.config.landscapeResolution)")
        print("Portrait: \(status.config.portraitDegree) deg \(status.config.portraitResolution)")
        print("Shortcut: \(status.config.hotKey.displayString)")
        print("Configured display: \(status.configuredDisplay == nil ? "not detected" : "detected")")
        if let savedState = status.config.lastKnownDisplayState {
            print("Restore last: available (\(savedState.degree) deg \(savedState.resolution))")
        } else {
            print("Restore last: unavailable")
        }
        print("")
        print("Detected displays:")
        if status.displays.isEmpty {
            print("- none")
        } else {
            for display in status.displays {
                let rotation = display.rotation.map { "\($0) deg" } ?? "-"
                let resolution = display.resolution ?? "-"
                let marker = display.persistentID == status.config.displayID ? " *" : ""
                print("- \(display.persistentID)\(marker) \(resolution) rotation \(rotation)")
            }
        }
    }

    private func printDoctor() throws {
        let status = try controller.status()
        var issues: [String] = []

        if status.displayPlacerPath == nil {
            issues.append("displayplacer is not available. Install it with: brew install displayplacer")
        }

        if status.config.displayID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("No display is configured. Run: st s")
        } else if status.displayPlacerPath != nil, status.configuredDisplay == nil {
            issues.append("Configured display was not detected. Run: st ls, then st use <display-id>")
        }

        do {
            try status.config.hotKey.validate()
        } catch {
            issues.append((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }

        print("ScreenTurn doctor")
        print("Config: \(configStore.configURL.path)")
        print("displayplacer: \(status.displayPlacerPath ?? "not found")")
        print("Configured display: \(status.config.displayID.isEmpty ? "-" : status.config.displayID)")
        print("Shortcut: \(status.config.hotKey.displayString)")
        print("Detected displays: \(status.displays.count)")

        if issues.isEmpty {
            print("Result: OK")
        } else {
            print("Result: needs attention")
            for issue in issues {
                print("- \(issue)")
            }
        }
    }

    private func open(_ url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ScreenTurnError.invalidConfig("Unable to open \(url.path)")
        }
    }

    private func printHelp() {
        print(
            """
            ScreenTurn

            Usage:
              st                      Toggle screen rotation
              st t                    Toggle screen rotation
              st s [display-id]       Detect display and write config
              st use <display-id>     Select a specific detected display
              st use --force <id>     Save a display ID without detection
              st restore              Restore the display state before the last toggle
              st status               Show config and detected displays
              st ls                   Alias for status
              st doctor               Check readiness before first trial
              st path                 Print the config file path
              st open                 Open the config file
              st -n                   Preview the toggle command without applying it
              st help                 Show this help

            Long command:
              screenturn              Same as st

            Options:
              -n, --dry-run           Preview displayplacer command
              -v, --version           Print version

            Config:
              ~/Library/Application Support/ScreenTurn/config.json
            """
        )
    }
}

private extension Array where Element == String {
    mutating func removeAllOptions(_ options: Set<String>) -> Bool {
        let originalCount = count
        removeAll { options.contains($0) }
        return count != originalCount
    }
}

do {
    try ScreenTurnCLI(arguments: Array(CommandLine.arguments.dropFirst())).run()
} catch {
    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    FileHandle.standardError.write(Data("ScreenTurn error: \(message)\n".utf8))
    exit(1)
}
