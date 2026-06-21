import Foundation
import ScreenTurnCore

struct SelfTest {
    private var failures = 0

    mutating func run() {
        testParsesDisplayPlacerListOutput()
        testInfersLandscapeAndPortraitResolutions()
        testBuildsDisplayPlacerCommand()
        testDisplayMatchesAnyKnownID()
        testConfigStoreUsesOverrideDirectory()
        testConfigStoreRoundTripsConfig()
        testLegacyConfigDecodesWithoutRestoreState()
        testConfiguresDisplayFromDetectedInfo()
        testPlansRestoreFromSavedState()
        testDefaultHotKeyDisplaysAsSymbols()
        testValidatesKnownKeys()
        testRejectsUnknownKeys()
        testResolvesRecordedKeyCode()

        if failures == 0 {
            print("ScreenTurnSelfTest passed")
        } else {
            print("ScreenTurnSelfTest failed: \(failures) failure(s)")
            exit(1)
        }
    }

    private mutating func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    private mutating func testParsesDisplayPlacerListOutput() {
        let output = """
        Persistent screen id: 7787EBB5-2CC6-4199-AF58-5836F504166D
        Contextual screen id: 1
        Serial screen id: s123456
        Type: 27 inch external screen
        Resolution: 1920x1080
        Hertz: 60
        Color Depth: 8
        Scaling: on
        Origin: (0,0) - main display
        Rotation: 0

        Persistent screen id: SECOND-DISPLAY
        Contextual screen id: 2
        Type: 24 inch external screen
        Resolution: 1080x1920
        Hertz: 60
        Color Depth: 8
        Scaling: on
        Origin: (1920,0)
        Rotation: 270
        """

        let displays = DisplayPlacerListParser.parse(output)

        expect(displays.count == 2, "expected two displays")
        expect(displays[0].persistentID == "7787EBB5-2CC6-4199-AF58-5836F504166D", "persistent ID parsed")
        expect(displays[0].resolution == "1920x1080", "resolution parsed")
        expect(displays[0].hertz == 60, "hertz parsed")
        expect(displays[0].colorDepth == 8, "color depth parsed")
        expect(displays[0].scaling == "on", "scaling parsed")
        expect(displays[0].origin == "(0,0)", "origin parsed")
        expect(displays[0].rotation == 0, "rotation parsed")
        expect(displays[0].isMain, "main display parsed")
        expect(displays[1].persistentID == "SECOND-DISPLAY", "second display parsed")
        expect(displays[1].rotation == 270, "second rotation parsed")
    }

    private mutating func testInfersLandscapeAndPortraitResolutions() {
        let landscape = ScreenTurnController.inferResolutions(from: "1920x1080")
        expect(landscape?.landscape == "1920x1080", "landscape resolution preserved")
        expect(landscape?.portrait == "1080x1920", "portrait resolution inferred")

        let portrait = ScreenTurnController.inferResolutions(from: "1080x1920")
        expect(portrait?.landscape == "1920x1080", "landscape resolution inferred")
        expect(portrait?.portrait == "1080x1920", "portrait resolution preserved")
    }

    private mutating func testBuildsDisplayPlacerCommand() {
        let command = ScreenTurnController.command(
            displayID: "DISPLAY",
            resolution: "1080x1920",
            hertz: 60,
            colorDepth: 8,
            scaling: "on",
            origin: "(0,0)",
            degree: 270
        )

        expect(
            command == "id:DISPLAY res:1080x1920 hz:60 color_depth:8 enabled:true scaling:on origin:(0,0) degree:270",
            "displayplacer command built"
        )
    }

    private mutating func testDisplayMatchesAnyKnownID() {
        let display = DisplayInfo(
            persistentID: "PERSISTENT",
            contextualID: "1",
            serialID: "SERIAL"
        )

        expect(display.matches("PERSISTENT"), "display matches persistent ID")
        expect(display.matches("1"), "display matches contextual ID")
        expect(display.matches("SERIAL"), "display matches serial ID")
        expect(!display.matches("OTHER"), "display rejects unknown ID")
    }

    private mutating func testConfigStoreUsesOverrideDirectory() {
        let override = ProcessInfo.processInfo.environment["SCREENTURN_CONFIG_DIR"]
        guard let override else {
            return
        }

        let store = ConfigStore()
        expect(store.appSupportDirectory.path == override, "config directory override")
        expect(store.configURL.path == "\(override)/config.json", "config file override")
    }

    private mutating func testConfigStoreRoundTripsConfig() {
        let store = ConfigStore()
        var config = ScreenTurnConfig.default
        config.displayID = "TEST-DISPLAY"
        config.hotKey = HotKeyConfig(key: "T", modifiers: [.control, .option])
        config.lastKnownDisplayState = SavedDisplayState(
            resolution: "1080x1920",
            degree: 270,
            hertz: 60,
            colorDepth: 8,
            scaling: "on",
            origin: "(0,0)"
        )

        do {
            try store.save(config)
            let loadedConfig = try store.load()
            expect(loadedConfig == config, "config round-trips through disk")
        } catch {
            expect(false, "config should save and load: \(error)")
        }
    }

    private mutating func testConfiguresDisplayFromDetectedInfo() {
        let display = DisplayInfo(
            persistentID: "SECOND-DISPLAY",
            resolution: "1080x1920",
            hertz: 75,
            colorDepth: 10,
            scaling: "off",
            origin: "(1920,0)",
            rotation: 270
        )
        var existing = ScreenTurnConfig.default
        existing.lastKnownDisplayState = SavedDisplayState(
            resolution: "1920x1080",
            degree: 0,
            hertz: 60,
            colorDepth: 8,
            scaling: "on",
            origin: "(0,0)"
        )

        let config = ScreenTurnController.configuredConfig(existing, for: display)

        expect(config.displayID == "SECOND-DISPLAY", "selected display ID saved")
        expect(config.landscapeResolution == "1920x1080", "landscape resolution inferred for selected display")
        expect(config.portraitResolution == "1080x1920", "portrait resolution inferred for selected display")
        expect(config.hertz == 75, "selected display refresh rate saved")
        expect(config.colorDepth == 10, "selected display color depth saved")
        expect(config.portraitDegree == 270, "selected display rotation saved")
        expect(config.lastKnownDisplayState == nil, "changing displays clears restore state")
    }

    private mutating func testLegacyConfigDecodesWithoutRestoreState() {
        let legacyJSON = """
        {
          "colorDepth": 8,
          "displayID": "LEGACY-DISPLAY",
          "hertz": 60,
          "hotKey": {
            "key": "R",
            "modifiers": ["control", "option"]
          },
          "landscapeDegree": 0,
          "landscapeResolution": "1920x1080",
          "origin": "(0,0)",
          "portraitDegree": 270,
          "portraitResolution": "1080x1920",
          "scaling": "on"
        }
        """

        do {
            let config = try JSONDecoder().decode(ScreenTurnConfig.self, from: Data(legacyJSON.utf8))
            expect(config.lastKnownDisplayState == nil, "legacy config decodes without restore state")
        } catch {
            expect(false, "legacy config should decode: \(error)")
        }
    }

    private mutating func testPlansRestoreFromSavedState() {
        let store = ConfigStore()
        var config = ScreenTurnConfig.default
        config.displayID = "RESTORE-DISPLAY"
        config.lastKnownDisplayState = SavedDisplayState(
            resolution: "1920x1080",
            degree: 0,
            hertz: 60,
            colorDepth: 8,
            scaling: "on",
            origin: "(0,0)"
        )

        do {
            try store.save(config)
            let controller = ScreenTurnController(configStore: store)
            let plan = try controller.planRestoreLastKnownDisplayState()
            expect(plan.displayID == "RESTORE-DISPLAY", "restore plan keeps display ID")
            expect(plan.degree == 0, "restore plan keeps saved degree")
            expect(plan.resolution == "1920x1080", "restore plan keeps saved resolution")
            expect(
                plan.command == "id:RESTORE-DISPLAY res:1920x1080 hz:60 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0",
                "restore plan builds displayplacer command"
            )
        } catch {
            expect(false, "restore plan should be created: \(error)")
        }
    }

    private mutating func testDefaultHotKeyDisplaysAsSymbols() {
        expect(HotKeyConfig.default.displayString == "⌃⌥⌘R", "default hotkey display string")
    }

    private mutating func testValidatesKnownKeys() {
        let hotKey = HotKeyConfig(key: "F12", modifiers: [.control, .shift])
        do {
            try hotKey.validate()
            expect(hotKey.displayString == "⌃⇧F12", "custom hotkey display string")
        } catch {
            expect(false, "known hotkey should validate")
        }
    }

    private mutating func testRejectsUnknownKeys() {
        let hotKey = HotKeyConfig(key: "NOPE", modifiers: [.command])
        do {
            try hotKey.validate()
            expect(false, "unknown hotkey should fail")
        } catch {
            expect(true, "unknown hotkey failed")
        }
    }

    private mutating func testResolvesRecordedKeyCode() {
        expect(KeyCodeCatalog.key(for: 0x0F) == "R", "recorded R key code resolves")
        expect(KeyCodeCatalog.key(for: 0x24) == "RETURN", "recorded Return key code resolves")
        expect(KeyCodeCatalog.key(for: 0xFF) == nil, "unknown key code is rejected")
    }
}

var test = SelfTest()
test.run()
