import AppKit
import SwiftUI
import Carbon.HIToolbox

final class TranslationPanel: NSPanel {
    var onSettingsClicked: (() -> Void)?
    private var globalMouseMonitor: Any?
    private var globalKeyMonitor: Any?
    private var localMonitor: Any?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 160),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        commonSetup()
    }

    private func commonSetup() {
        isFloatingPanel = true
        level = .popUpMenu
        hasShadow = true
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
    }

    func configure(
        sourceText: String,
        translatedText: String?,
        isLoading: Bool,
        errorMessage: String? = nil
    ) {
        let root = TranslationPanelContent(
            sourceText: sourceText,
            translatedText: translatedText,
            isLoading: isLoading,
            errorMessage: errorMessage,
            onSettings: { [weak self] in self?.onSettingsClicked?() },
            onClose: { [weak self] in AppDelegate.shared?.closeTranslationPanel() }
        )
        let host = NSHostingView(rootView: root)
        self.contentView = host
    }

    func position(at screenPoint: NSPoint) {
        let contentSize = contentView?.fittingSize ?? NSSize(width: 360, height: 200)
        setContentSize(contentSize)

        var origin = NSPoint(
            x: screenPoint.x - 16,
            y: screenPoint.y - contentSize.height - 16
        )

        if let screen = NSScreen.screens.first(where: { NSMouseInRect(screenPoint, $0.frame, false) }) {
            let visible = screen.visibleFrame
            if origin.x < visible.minX { origin.x = visible.minX }
            if origin.y < visible.minY {
                origin.y = screenPoint.y + 20
            }
            if origin.x + contentSize.width > visible.maxX {
                origin.x = visible.maxX - contentSize.width
            }
            if origin.y + contentSize.height > visible.maxY {
                origin.y = visible.maxY - contentSize.height
            }
        }

        setFrameOrigin(origin)
    }

    override func orderFrontRegardless() {
        super.orderFrontRegardless()
        installMonitors()
    }

    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
        removeMonitors()
    }

    private func installMonitors() {
        removeMonitors()

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closeByClickOutside() }
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            Task { @MainActor in
                if event.keyCode == kVK_Escape {
                    AppDelegate.shared?.closeTranslationPanel()
                }
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]) { [weak self] event in
            guard let self = self else { return event }
            if event.type == .keyDown {
                if event.keyCode == kVK_Escape {
                    Task { @MainActor in AppDelegate.shared?.closeTranslationPanel() }
                    return nil
                }
                return event
            }
            let screenPoint = event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
            if !self.frame.contains(screenPoint) {
                Task { @MainActor in self.closeByClickOutside() }
            }
            return event
        }
    }

    private func removeMonitors() {
        if let m = globalMouseMonitor { NSEvent.removeMonitor(m); globalMouseMonitor = nil }
        if let m = globalKeyMonitor { NSEvent.removeMonitor(m); globalKeyMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }

    @MainActor
    private func closeByClickOutside() {
        let mouse = NSEvent.mouseLocation
        if !frame.contains(mouse) {
            AppDelegate.shared?.closeTranslationPanel()
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func makeKey() { }
}

private struct TranslationPanelContent: View {
    let sourceText: String
    let translatedText: String?
    let isLoading: Bool
    let errorMessage: String?
    let onSettings: () -> Void
    let onClose: () -> Void

    @State private var copyFlash = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)

            VStack(alignment: .leading, spacing: 8) {
                Text(sourceText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider().opacity(0.4)

                Group {
                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(LocalizationManager.localized("translation.loading"))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    } else if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    } else if let translated = translatedText {
                        Text(translated)
                            .font(.system(size: 13, weight: .medium))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)

                if !isLoading, errorMessage == nil, let translated = translatedText {
                    HStack(spacing: 6) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(translated, forType: .string)
                            withAnimation(.easeInOut(duration: 0.15)) { copyFlash = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                withAnimation(.easeInOut(duration: 0.15)) { copyFlash = false }
                            }
                        } label: {
                            Image(systemName: copyFlash ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .frame(width: 22, height: 22)
                        .help(LocalizationManager.localized("translation.copy_hint"))

                        Spacer()

                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 22, height: 22)
                        .help(LocalizationManager.localized("translation.close_hint"))
                    }
                }
            }
            .padding(EdgeInsets(top: 28, leading: 12, bottom: 10, trailing: 12))

            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)
            .padding(EdgeInsets(top: 6, leading: 0, bottom: 0, trailing: 6))
        }
        .frame(width: 280)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        v.isEmphasized = false
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
