import AppKit
import ScreenTurnCore

struct SettingsDraft {
    var hotKey: HotKeyConfig
    var selectedDisplay: DisplayInfo?
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onSave: ((SettingsDraft) throws -> Void)?
    var onRefreshDisplays: ((@escaping (Result<[DisplayInfo], Error>) -> Void) -> Void)?
    var onClose: (() -> Void)?

    private let displayPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let refreshButton = NSButton()
    private let shortcutRecorder = ShortcutRecorderView()
    private let feedbackLabel = NSTextField(wrappingLabelWithString: "")
    private var detectedDisplays: [DisplayInfo] = []
    private var configuredDisplayID: String

    init(config: ScreenTurnConfig, displays: [DisplayInfo]) {
        configuredDisplayID = config.displayID

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 418),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ScreenTurn Settings"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self
        configureWindow(config: config, displays: displays)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    private func configureWindow(config: ScreenTurnConfig, displays: [DisplayInfo]) {
        guard let window else {
            return
        }

        let contentView = NSView()
        window.contentView = contentView

        let titleLabel = NSTextField(labelWithString: "ScreenTurn Settings")
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)

        let displayTitleLabel = NSTextField(labelWithString: "Target Display")
        displayTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        displayPopup.controlSize = .regular
        displayPopup.setContentHuggingPriority(.defaultLow, for: .horizontal)
        populateDisplays(displays, selecting: config.displayID)

        if let image = NSImage(
            systemSymbolName: "arrow.clockwise",
            accessibilityDescription: "Refresh detected displays"
        ) {
            refreshButton.image = image
            refreshButton.title = ""
        } else {
            refreshButton.title = "Refresh"
        }
        refreshButton.bezelStyle = .texturedRounded
        refreshButton.toolTip = "Refresh detected displays"
        refreshButton.target = self
        refreshButton.action = #selector(refreshDisplays)

        let displayRow = NSStackView(views: [displayPopup, refreshButton])
        displayRow.orientation = .horizontal
        displayRow.alignment = .centerY
        displayRow.spacing = 8

        let displayHintLabel = NSTextField(
            wrappingLabelWithString: "Selecting a display updates its stored rotation and resolution settings."
        )
        displayHintLabel.textColor = .tertiaryLabelColor
        displayHintLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        let displaySeparator = NSBox()
        displaySeparator.boxType = .separator

        let shortcutTitleLabel = NSTextField(labelWithString: "Keyboard Shortcut")
        shortcutTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        let shortcutDescriptionLabel = NSTextField(
            wrappingLabelWithString: "Click the shortcut field, then press a key with Control, Option, Shift, or Command."
        )
        shortcutDescriptionLabel.textColor = .secondaryLabelColor
        shortcutDescriptionLabel.maximumNumberOfLines = 2

        shortcutRecorder.hotKey = config.hotKey
        shortcutRecorder.onChange = { [weak self] result in
            switch result {
            case let .success(hotKey):
                self?.feedbackLabel.stringValue = "Ready to save \(hotKey.displayString)."
                self?.feedbackLabel.textColor = .secondaryLabelColor
            case let .failure(error):
                self?.feedbackLabel.stringValue = error.localizedDescription
                self?.feedbackLabel.textColor = .systemRed
            }
        }

        let restoreShortcutButton = NSButton(
            title: "Restore Default",
            target: self,
            action: #selector(restoreDefaultShortcut)
        )
        restoreShortcutButton.controlSize = .small

        let shortcutHintLabel = NSTextField(
            wrappingLabelWithString: "Press Escape without modifiers to cancel recording. A modifier is required."
        )
        shortcutHintLabel.textColor = .tertiaryLabelColor
        shortcutHintLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        feedbackLabel.stringValue = "Current shortcut: \(config.hotKey.displayString)"
        feedbackLabel.textColor = .secondaryLabelColor
        feedbackLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        let footerSeparator = NSBox()
        footerSeparator.boxType = .separator

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1B}"

        let saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        saveButton.bezelStyle = .rounded

        let buttonSpacer = NSView()
        buttonSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let buttonRow = NSStackView(views: [buttonSpacer, cancelButton, saveButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8

        let stack = NSStackView(views: [
            titleLabel,
            displayTitleLabel,
            displayRow,
            displayHintLabel,
            displaySeparator,
            shortcutTitleLabel,
            shortcutDescriptionLabel,
            shortcutRecorder,
            restoreShortcutButton,
            shortcutHintLabel,
            feedbackLabel,
            footerSeparator,
            buttonRow
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            displayRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            displayPopup.widthAnchor.constraint(equalTo: displayRow.widthAnchor, constant: -38),
            shortcutRecorder.widthAnchor.constraint(equalTo: stack.widthAnchor),
            shortcutRecorder.heightAnchor.constraint(equalToConstant: 46),
            displaySeparator.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footerSeparator.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    @objc private func refreshDisplays() {
        guard let onRefreshDisplays else {
            return
        }

        refreshButton.isEnabled = false
        feedbackLabel.stringValue = "Refreshing detected displays..."
        feedbackLabel.textColor = .secondaryLabelColor
        let selectedDisplayID = selectedDisplayID

        onRefreshDisplays { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                self.refreshButton.isEnabled = true
                switch result {
                case let .success(displays):
                    self.populateDisplays(displays, selecting: selectedDisplayID)
                    self.feedbackLabel.stringValue = displays.isEmpty
                        ? "No displays detected."
                        : "Detected \(displays.count) display(s)."
                    self.feedbackLabel.textColor = displays.isEmpty ? .systemRed : .secondaryLabelColor
                case let .failure(error):
                    self.feedbackLabel.stringValue = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    self.feedbackLabel.textColor = .systemRed
                }
            }
        }
    }

    @objc private func restoreDefaultShortcut() {
        shortcutRecorder.hotKey = .default
        feedbackLabel.stringValue = "Default shortcut restored: \(HotKeyConfig.default.displayString)"
        feedbackLabel.textColor = .secondaryLabelColor
    }

    @objc private func cancel() {
        close()
    }

    @objc private func save() {
        guard let hotKey = shortcutRecorder.hotKey else {
            feedbackLabel.stringValue = "Record a shortcut before saving."
            feedbackLabel.textColor = .systemRed
            return
        }

        do {
            try hotKey.validate()
            guard let onSave else {
                throw ScreenTurnError.invalidConfig("The settings window is not connected to ScreenTurn.")
            }
            try onSave(
                SettingsDraft(
                    hotKey: hotKey,
                    selectedDisplay: selectedDisplay
                )
            )
            close()
        } catch {
            feedbackLabel.stringValue = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            feedbackLabel.textColor = .systemRed
        }
    }

    private var selectedDisplayID: String {
        (displayPopup.selectedItem?.representedObject as? String) ?? configuredDisplayID
    }

    private var selectedDisplay: DisplayInfo? {
        detectedDisplays.first { $0.persistentID == selectedDisplayID }
    }

    private func populateDisplays(_ displays: [DisplayInfo], selecting displayID: String) {
        detectedDisplays = displays
        configuredDisplayID = displayID
        displayPopup.removeAllItems()

        guard !displays.isEmpty else {
            displayPopup.addItem(withTitle: "No displays detected")
            displayPopup.isEnabled = false
            return
        }

        displayPopup.isEnabled = true

        for display in displays {
            displayPopup.addItem(withTitle: displayTitle(for: display))
            displayPopup.lastItem?.representedObject = display.persistentID
        }

        if let selectedItem = displayPopup.itemArray.first(where: {
            ($0.representedObject as? String) == displayID
        }) {
            displayPopup.select(selectedItem)
        } else {
            displayPopup.selectItem(at: 0)
        }
    }

    private func displayTitle(for display: DisplayInfo) -> String {
        let type = display.type ?? "Display"
        let resolution = display.resolution ?? "Unknown resolution"
        let rotation = display.rotation.map { " \($0) deg" } ?? ""
        let shortID = String(display.persistentID.prefix(8))
        return "\(type) - \(resolution)\(rotation) [\(shortID)]"
    }
}

private final class ShortcutRecorderView: NSView {
    var hotKey: HotKeyConfig? {
        didSet {
            needsDisplay = true
        }
    }

    var onChange: ((Result<HotKeyConfig, Error>) -> Void)?

    private var isRecording = false {
        didSet {
            needsDisplay = true
        }
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let modifiers = hotKeyModifiers(from: event.modifierFlags)

        if event.keyCode == 0x35, modifiers.isEmpty {
            isRecording = false
            return
        }

        guard let key = KeyCodeCatalog.key(for: UInt32(event.keyCode)) else {
            onChange?(.failure(ScreenTurnError.unsupportedHotKey(event.charactersIgnoringModifiers ?? "Unknown")))
            return
        }

        let capturedHotKey = HotKeyConfig(key: key, modifiers: modifiers)

        do {
            try capturedHotKey.validate()
            hotKey = capturedHotKey
            isRecording = false
            onChange?(.success(capturedHotKey))
        } catch {
            onChange?(.failure(error))
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let cornerRadius: CGFloat = 7
        let backgroundColor = isRecording
            ? NSColor.controlAccentColor.withAlphaComponent(0.12)
            : NSColor.controlBackgroundColor
        let borderColor = isRecording ? NSColor.controlAccentColor : NSColor.separatorColor

        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: cornerRadius, yRadius: cornerRadius)
        backgroundColor.setFill()
        path.fill()
        borderColor.setStroke()
        path.lineWidth = isRecording ? 2 : 1
        path.stroke()

        let text = isRecording ? "Press new shortcut" : (hotKey?.displayString ?? "Click to record")
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 17, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        (text as NSString).draw(in: textRect, withAttributes: attributes)
    }

    private func hotKeyModifiers(from flags: NSEvent.ModifierFlags) -> [HotKeyModifier] {
        let relevantFlags = flags.intersection(.deviceIndependentFlagsMask)
        var modifiers: [HotKeyModifier] = []

        if relevantFlags.contains(.control) {
            modifiers.append(.control)
        }
        if relevantFlags.contains(.option) {
            modifiers.append(.option)
        }
        if relevantFlags.contains(.shift) {
            modifiers.append(.shift)
        }
        if relevantFlags.contains(.command) {
            modifiers.append(.command)
        }

        return modifiers
    }
}
