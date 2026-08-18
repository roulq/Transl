import AppKit
import ApplicationServices
import Carbon.HIToolbox

final class AccessibilityManager {
    var isPermissionGranted: Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    func requestPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func captureSelectedText() async -> String {
        if isPermissionGranted, let axText = captureViaAX() {
            return axText
        }
        return await captureViaCopyPaste()
    }

    private func captureViaAX() -> String? {
        let systemElement = AXUIElementCreateSystemWide()

        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        guard result == .success,
              let element = focusedElement,
              CFGetTypeID(element) == AXUIElementGetTypeID() else {
            return nil
        }
        let axElement = element as! AXUIElement

        var selectedRangeValue: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeValue
        )
        guard rangeResult == .success,
              let value = selectedRangeValue,
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        let rangeValue = value as! AXValue

        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(rangeValue, .cfRange, &range) else { return nil }
        guard range.length > 0 else { return nil }

        var selectedText: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )
        if textResult == .success, let text = selectedText as? String, !text.isEmpty {
            return text
        }

        var fullValue: AnyObject?
        if AXUIElementCopyAttributeValue(
            axElement,
            kAXValueAttribute as CFString,
            &fullValue
        ) == .success, let fullText = fullValue as? String {
            let nsRange = NSRange(location: range.location, length: range.length)
            if let swiftRange = Range(nsRange, in: fullText) {
                return String(fullText[swiftRange])
            }
        }

        return nil
    }

    @MainActor
    private func captureViaCopyPaste() async -> String {
        let pasteboard = NSPasteboard.general

        typealias ItemData = [(type: NSPasteboard.PasteboardType, data: Data)]
        var savedItems: [ItemData] = []
        for item in pasteboard.pasteboardItems ?? [] {
            var itemData: ItemData = []
            for type in item.types {
                if let data = item.data(forType: type) {
                    itemData.append((type: type, data: data))
                }
            }
            savedItems.append(itemData)
        }

        defer {
            pasteboard.clearContents()
            for itemData in savedItems {
                let pbItem = NSPasteboardItem()
                for entry in itemData {
                    pbItem.setData(entry.data, forType: entry.type)
                }
                pasteboard.writeObjects([pbItem])
            }
        }

        let source = CGEventSource(stateID: .combinedSessionState)

        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_ANSI_C), keyDown: true)
        cmdDown?.flags = CGEventFlags.maskCommand

        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: UInt16(kVK_ANSI_C), keyDown: false)
        cmdUp?.flags = CGEventFlags.maskCommand

        cmdDown?.post(tap: CGEventTapLocation.cghidEventTap)
        cmdUp?.post(tap: CGEventTapLocation.cghidEventTap)

        try? await Task.sleep(nanoseconds: 100_000_000)

        let newString = pasteboard.string(forType: .string) ?? ""
        return newString
    }
}
