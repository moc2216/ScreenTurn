import Carbon
import Foundation
import ScreenTurnCore

final class HotKeyRegistrar {
    var onHotKey: (() -> Void)?

    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?

    init() throws {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard status == noErr else {
            throw ScreenTurnError.invalidConfig("Unable to install hotkey event handler: \(status)")
        }
    }

    deinit {
        unregister()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func register(_ config: HotKeyConfig) throws {
        unregister()
        try config.validate()

        guard let keyCode = config.keyCode else {
            throw ScreenTurnError.unsupportedHotKey(config.key)
        }

        let hotKeyID = EventHotKeyID(signature: fourCharCode("STrn"), id: 1)
        var newHotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifierFlags(for: config.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &newHotKeyRef
        )

        guard status == noErr else {
            throw ScreenTurnError.invalidConfig("Unable to register hotkey \(config.displayString): \(status)")
        }

        hotKeyRef = newHotKeyRef
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}

private let hotKeyEventHandler: EventHandlerUPP = { _, _, userData in
    guard let userData else {
        return noErr
    }

    let registrar = Unmanaged<HotKeyRegistrar>
        .fromOpaque(userData)
        .takeUnretainedValue()

    DispatchQueue.main.async {
        registrar.onHotKey?()
    }

    return noErr
}

private func modifierFlags(for modifiers: [HotKeyModifier]) -> UInt32 {
    var flags: UInt32 = 0

    if modifiers.contains(.command) {
        flags |= UInt32(cmdKey)
    }
    if modifiers.contains(.option) {
        flags |= UInt32(optionKey)
    }
    if modifiers.contains(.control) {
        flags |= UInt32(controlKey)
    }
    if modifiers.contains(.shift) {
        flags |= UInt32(shiftKey)
    }

    return flags
}

private func fourCharCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { result, character in
        (result << 8) + OSType(character)
    }
}
