import AppKit
import ScreenTurnCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let configStore = ConfigStore()
    private lazy var controller = ScreenTurnController(configStore: configStore)
    private var hotKeyRegistrar: HotKeyRegistrar?
    private var settingsWindowController: SettingsWindowController?
    private var displayStatus: Result<ScreenTurnStatus, Error>?
    private var isRefreshingDisplayStatus = false
    private var isBusy = false
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()

    private let toggleItem = NSMenuItem(title: "Toggle Rotation", action: #selector(toggleRotation), keyEquivalent: "")
    private let restoreItem = NSMenuItem(title: "Restore Last Rotation", action: #selector(restoreLastRotation), keyEquivalent: "")
    private let displayStatusItem = NSMenuItem(title: "Display: Checking...", action: nil, keyEquivalent: "")
    private let shortcutItem = NSMenuItem(title: "Shortcut: -", action: nil, keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: "")
    private let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let setupItem = NSMenuItem(title: "Setup / Re-detect Display", action: #selector(setupDisplay), keyEquivalent: "")
    private let openConfigItem = NSMenuItem(title: "Open Config", action: #selector(openConfig), keyEquivalent: "")
    private let reloadConfigItem = NSMenuItem(title: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configureMenu()
        loadConfigAndRegisterHotKey(showErrors: true)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        if let image = NSImage(
            systemSymbolName: "arrow.triangle.2.circlepath",
            accessibilityDescription: "ScreenTurn"
        ) {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "ST"
        }

        button.toolTip = "ScreenTurn"
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configureMenu() {
        menu.delegate = self

        for item in [
            toggleItem,
            restoreItem,
            displayStatusItem,
            NSMenuItem.separator(),
            shortcutItem,
            settingsItem,
            launchAtLoginItem,
            NSMenuItem.separator(),
            setupItem,
            openConfigItem,
            reloadConfigItem,
            NSMenuItem.separator(),
            NSMenuItem(title: "Quit ScreenTurn", action: #selector(quit), keyEquivalent: "q")
        ] {
            item.target = self
            menu.addItem(item)
        }

        shortcutItem.isEnabled = false
        displayStatusItem.isEnabled = false
        restoreItem.isEnabled = false
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenu()
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else {
            toggleRotation()
            return
        }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            toggleRotation()
        }
    }

    private func showMenu() {
        updateMenu()
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleRotation() {
        guard !isBusy else {
            return
        }

        guard canToggle else {
            showMenu()
            return
        }

        setBusy(true)

        DispatchQueue.global(qos: .userInitiated).async { [controller] in
            let result = Result {
                try controller.toggle()
            }

            DispatchQueue.main.async { [weak self] in
                self?.setBusy(false)

                switch result {
                case let .success(toggleResult):
                    self?.statusItem.button?.toolTip = "ScreenTurn: \(toggleResult.toDegree)° \(toggleResult.resolution)"
                    self?.refreshDisplayStatus()
                case let .failure(error):
                    self?.showError(error)
                }
            }
        }
    }

    @objc private func setupDisplay() {
        setBusy(true)

        DispatchQueue.global(qos: .userInitiated).async { [controller] in
            let result = Result {
                try controller.configureFromCurrentDisplay()
            }

            DispatchQueue.main.async { [weak self] in
                self?.setBusy(false)

                switch result {
                case let .success(config):
                    self?.registerHotKey(from: config, showErrors: true)
                    self?.updateMenu()
                    self?.statusItem.button?.toolTip = "ScreenTurn: configured \(config.displayID)"
                    self?.refreshDisplayStatus()
                case let .failure(error):
                    self?.showError(error)
                }
            }
        }
    }

    @objc private func restoreLastRotation() {
        guard !isBusy else {
            return
        }

        setBusy(true)

        DispatchQueue.global(qos: .userInitiated).async { [controller] in
            let result = Result {
                try controller.restoreLastKnownDisplayState()
            }

            DispatchQueue.main.async { [weak self] in
                self?.setBusy(false)

                switch result {
                case let .success(restoreResult):
                    self?.statusItem.button?.toolTip = "ScreenTurn: restored \(restoreResult.degree)° \(restoreResult.resolution)"
                    self?.updateMenu()
                    self?.refreshDisplayStatus()
                case let .failure(error):
                    self?.showError(error)
                }
            }
        }
    }

    @objc private func openConfig() {
        do {
            _ = try configStore.loadOrCreateDefault()
            NSWorkspace.shared.open(configStore.configURL)
        } catch {
            showError(error)
        }
    }

    @objc private func openSettings() {
        if let settingsWindowController {
            settingsWindowController.present()
            return
        }

        do {
            let config = try configStore.loadOrCreateDefault()
            hotKeyRegistrar?.unregister()

            let displays: [DisplayInfo]
            if case let .success(status)? = displayStatus {
                displays = status.displays
            } else {
                displays = []
            }

            let settingsWindowController = SettingsWindowController(config: config, displays: displays)
            settingsWindowController.onSave = { [weak self] draft in
                guard let self else {
                    return
                }
                try self.saveSettings(draft)
            }
            settingsWindowController.onRefreshDisplays = { [weak self] completion in
                guard let self else {
                    completion(.failure(ScreenTurnError.invalidConfig("ScreenTurn is no longer running.")))
                    return
                }

                DispatchQueue.global(qos: .utility).async { [controller] in
                    let result: Result<ScreenTurnStatus, Error> = Result {
                        try controller.status()
                    }

                    DispatchQueue.main.async {
                        switch result {
                        case let .success(status):
                            self.displayStatus = .success(status)
                            self.updateDisplayStatusItem()
                            completion(.success(status.displays))
                        case let .failure(error):
                            completion(.failure(error))
                        }
                    }
                }
            }
            settingsWindowController.onClose = { [weak self] in
                self?.settingsWindowController = nil
                self?.loadConfigAndRegisterHotKey(showErrors: false)
            }
            self.settingsWindowController = settingsWindowController
            settingsWindowController.present()
        } catch {
            showError(error)
        }
    }

    @objc private func reloadConfig() {
        loadConfigAndRegisterHotKey(showErrors: true)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            updateMenu()
        } catch {
            showError(error)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func loadConfigAndRegisterHotKey(showErrors: Bool) {
        do {
            let config = try configStore.loadOrCreateDefault()
            try config.hotKey.validate()
            registerHotKey(from: config, showErrors: showErrors)
            updateMenu()
        } catch {
            if showErrors {
                showError(error)
            }
        }
    }

    private func registerHotKey(from config: ScreenTurnConfig, showErrors: Bool) {
        do {
            try registerHotKey(config.hotKey)
        } catch {
            if showErrors {
                showError(error)
            }
        }
    }

    private func updateMenu() {
        if let config = try? configStore.loadOrCreateDefault() {
            shortcutItem.title = "Shortcut: \(config.hotKey.displayString)"
            restoreItem.isEnabled = !isBusy && config.lastKnownDisplayState != nil
        } else {
            shortcutItem.title = "Shortcut: -"
            restoreItem.isEnabled = false
        }

        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLoginItem.state = .on
        case .requiresApproval:
            launchAtLoginItem.state = .mixed
        default:
            launchAtLoginItem.state = .off
        }

        updateDisplayStatusItem()
        refreshDisplayStatus()
    }

    private func setBusy(_ isBusy: Bool) {
        self.isBusy = isBusy
        toggleItem.isEnabled = !isBusy && canToggle
        restoreItem.isEnabled = !isBusy && hasRestorableState
        setupItem.isEnabled = !isBusy
        settingsItem.isEnabled = !isBusy
        reloadConfigItem.isEnabled = !isBusy
    }

    private var canToggle: Bool {
        guard case let .success(status)? = displayStatus,
              status.displayPlacerError == nil,
              !status.config.displayID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              status.configuredDisplay != nil else {
            return false
        }

        return true
    }

    private var hasRestorableState: Bool {
        (try? configStore.loadOrCreateDefault())?.lastKnownDisplayState != nil
    }

    private func registerHotKey(_ hotKey: HotKeyConfig) throws {
        if hotKeyRegistrar == nil {
            hotKeyRegistrar = try HotKeyRegistrar()
            hotKeyRegistrar?.onHotKey = { [weak self] in
                self?.toggleRotation()
            }
        }

        guard let hotKeyRegistrar else {
            throw ScreenTurnError.invalidConfig("Unable to create the global hotkey registrar.")
        }

        try hotKeyRegistrar.register(hotKey)
    }

    private func saveSettings(_ draft: SettingsDraft) throws {
        try draft.hotKey.validate()
        let currentConfig = try configStore.loadOrCreateDefault()
        var updatedConfig = currentConfig

        if let selectedDisplay = draft.selectedDisplay,
           selectedDisplay.persistentID != currentConfig.displayID {
            updatedConfig = ScreenTurnController.configuredConfig(updatedConfig, for: selectedDisplay)
        }

        updatedConfig.hotKey = draft.hotKey

        do {
            try registerHotKey(draft.hotKey)
        } catch {
            try? registerHotKey(currentConfig.hotKey)
            throw error
        }

        do {
            try configStore.save(updatedConfig)
        } catch {
            try? registerHotKey(currentConfig.hotKey)
            throw error
        }

        updateMenu()
        refreshDisplayStatus()
    }

    private func refreshDisplayStatus() {
        guard !isRefreshingDisplayStatus else {
            return
        }

        isRefreshingDisplayStatus = true
        DispatchQueue.global(qos: .utility).async { [controller] in
            let result = Result {
                try controller.status()
            }

            DispatchQueue.main.async { [weak self] in
                self?.isRefreshingDisplayStatus = false
                self?.displayStatus = result
                self?.updateDisplayStatusItem()
            }
        }
    }

    private func updateDisplayStatusItem() {
        guard case let .success(status)? = displayStatus else {
            displayStatusItem.title = "Display: Checking..."
            displayStatusItem.toolTip = nil
            toggleItem.isEnabled = false
            return
        }

        if let displayPlacerError = status.displayPlacerError {
            displayStatusItem.title = "Display: displayplacer unavailable"
            displayStatusItem.toolTip = displayPlacerError
            toggleItem.isEnabled = false
            return
        }

        guard !status.config.displayID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            displayStatusItem.title = "Display: setup required"
            displayStatusItem.toolTip = "Choose Setup / Re-detect Display to configure a target screen."
            toggleItem.isEnabled = false
            return
        }

        guard let display = status.configuredDisplay else {
            displayStatusItem.title = "Display: not connected"
            displayStatusItem.toolTip = "Configured display \(status.config.displayID) was not found."
            toggleItem.isEnabled = false
            return
        }

        let rotation = display.rotation ?? status.config.landscapeDegree
        let orientation: String
        if rotation == status.config.landscapeDegree {
            orientation = "Landscape"
        } else if rotation == status.config.portraitDegree {
            orientation = "Portrait"
        } else {
            orientation = "Rotation \(rotation)°"
        }

        let resolution = display.resolution ?? "Unknown resolution"
        displayStatusItem.title = "Display: \(orientation) - \(resolution)"
        displayStatusItem.toolTip = display.type ?? status.config.displayID
        toggleItem.isEnabled = !isBusy
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "ScreenTurn"
        alert.informativeText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
