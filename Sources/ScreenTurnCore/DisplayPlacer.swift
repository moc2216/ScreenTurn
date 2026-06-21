import Foundation

public final class DisplayPlacer {
    public let executablePath: String

    public init(executablePath: String) {
        self.executablePath = executablePath
    }

    public static func locate() throws -> DisplayPlacer {
        if let override = ProcessInfo.processInfo.environment["SCREENTURN_DISPLAYPLACER"],
           FileManager.default.isExecutableFile(atPath: override) {
            return DisplayPlacer(executablePath: override)
        }

        let candidates = [
            "/opt/homebrew/bin/displayplacer",
            "/usr/local/bin/displayplacer",
            "/usr/bin/displayplacer"
        ]

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return DisplayPlacer(executablePath: candidate)
        }

        throw ScreenTurnError.displayPlacerNotFound
    }

    public func listDisplays() throws -> [DisplayInfo] {
        let output = try run(arguments: ["list"], commandName: "list")
        return DisplayPlacerListParser.parse(output)
    }

    public func apply(_ command: String) throws {
        _ = try run(arguments: [command], commandName: command)
    }

    private func run(arguments: [String], commandName: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()
        process.waitUntilExit()

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw ScreenTurnError.displayPlacerFailed(
                command: commandName,
                status: process.terminationStatus,
                output: output
            )
        }

        return output
    }
}
