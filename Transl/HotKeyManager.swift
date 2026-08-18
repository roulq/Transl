import AppKit
import Carbon.HIToolbox

@MainActor
final class HotKeyManager {
    var onHotKeyTriggered: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var currentCombo: KeyCombo?

    deinit {
        Task { @MainActor [hotKeyRef, eventHandler] in
            if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
            if let handler = eventHandler { RemoveEventHandler(handler) }
        }
    }

    func register(keyCombo: KeyCombo) {
        unregister()
        currentCombo = keyCombo

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData -> OSStatus in
                guard let userData = userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if hotKeyID.id == 1 {
                    Task { @MainActor in
                        manager.onHotKeyTriggered?()
                    }
                }
                return noErr
            },
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        var hotKeyID = EventHotKeyID(signature: OSType(0x544C4E4C), id: 1)

        let modifiers = carbonModifiers(from: keyCombo.modifiers)

        RegisterEventHotKey(
            keyCombo.keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        currentCombo = nil
    }

    func update(keyCombo: KeyCombo) {
        register(keyCombo: keyCombo)
    }

    private func carbonModifiers(from cocoa: UInt32) -> UInt32 {
        var mods: UInt32 = 0
        if cocoa & UInt32(cmdKey) != 0 { mods |= UInt32(cmdKey) }
        if cocoa & UInt32(optionKey) != 0 { mods |= UInt32(optionKey) }
        if cocoa & UInt32(controlKey) != 0 { mods |= UInt32(controlKey) }
        if cocoa & UInt32(shiftKey) != 0 { mods |= UInt32(shiftKey) }
        return mods
    }
}

final class HotKeyRecorder: NSView {
    var onRecorded: ((KeyCombo) -> Void)?
    var isRecording = false {
        didSet { needsDisplay = true }
    }
    var currentCombo: KeyCombo? {
        didSet { needsDisplay = true }
    }

    private var monitor: Any?

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        (isRecording ? NSColor.selectedControlColor.withAlphaComponent(0.15) : NSColor.controlBackgroundColor).setFill()
        path.fill()

        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        let text: String
        if isRecording {
            text = LocalizationManager.localized("settings.recording_hint")
        } else if let combo = currentCombo {
            text = combo.displayString
        } else {
            text = LocalizationManager.localized("settings.click_to_record")
        }

        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: style
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let rect = NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        (text as NSString).draw(in: rect, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
        startMonitor()
    }

    private func startMonitor() {
        stopMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isRecording else { return event }

            let modifiers = event.modifierFlags.carbonModifiers
            if modifiers == 0 { return event }
            if event.keyCode == kVK_Escape {
                self.isRecording = false
                self.stopMonitor()
                return nil
            }

            let combo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers)
            self.currentCombo = combo
            self.onRecorded?(combo)
            self.isRecording = false
            self.stopMonitor()
            return nil
        }
    }

    private func stopMonitor() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        stopMonitor()
        return super.resignFirstResponder()
    }
}

extension NSEvent.ModifierFlags {
    var carbonModifiers: UInt32 {
        var mods: UInt32 = 0
        if contains(.command) { mods |= UInt32(cmdKey) }
        if contains(.option) { mods |= UInt32(optionKey) }
        if contains(.control) { mods |= UInt32(controlKey) }
        if contains(.shift) { mods |= UInt32(shiftKey) }
        return mods
    }
}
