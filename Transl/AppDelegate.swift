import AppKit
import SwiftUI
import Carbon.HIToolbox
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate!

    private let settings = AppSettings.shared
    private let hotKeyManager = HotKeyManager()
    private let accessibilityManager = AccessibilityManager()
    private let translationService = TranslationService()
    private var translationPanel: TranslationPanel?
    private var settingsWindow: NSWindow?
    private var isFirstLaunch = false
    private var languageChangeCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        _ = LocalizationManager.shared

        languageChangeCancellable = LocalizationManager.shared.$currentLanguage
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateSettingsWindowTitle()
                }
            }

        NSApp.setActivationPolicy(.accessory)

        isFirstLaunch = !UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showSettingsWindow()
            }
        }

        hotKeyManager.onHotKeyTriggered = { [weak self] in
            self?.handleHotKey()
        }

        hotKeyManager.register(keyCombo: settings.hotKeyCombo)
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyManager.unregister()
        languageChangeCancellable?.cancel()
    }

    @MainActor
    private func handleHotKey() {
        Task {
            guard accessibilityManager.isPermissionGranted else {
                showAccessibilityRequiredNotification()
                return
            }

            closeTranslationPanel()

            let text = await accessibilityManager.captureSelectedText()
            guard !text.isEmpty else { return }

            showTranslationPanel(sourceText: text, at: NSEvent.mouseLocation)

            let result = await translationService.translateWithFallback(
                text: text,
                targetLanguageCode: settings.targetLanguageCode,
                fallbackLanguageCode: settings.fallbackLanguageCode
            )

            updateTranslationPanel(with: result, sourceText: text)

            if settings.autoCopyResult, case .success(let translated) = result {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(translated, forType: .string)
            }
        }
    }

    @MainActor
    private func showAccessibilityRequiredNotification() {
        let alert = NSAlert()
        alert.messageText = LocalizationManager.localized("settings.accessibility")
        alert.informativeText = LocalizationManager.localized("error.accessibility_required")
        alert.alertStyle = .warning
        alert.addButton(withTitle: LocalizationManager.localized("settings.open_system_settings"))
        alert.addButton(withTitle: LocalizationManager.localized("settings.no_access"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            accessibilityManager.openAccessibilitySettings()
        }
    }

    @MainActor
    private func showTranslationPanel(sourceText: String, at point: NSPoint) {
        let panel = TranslationPanel()
        panel.onSettingsClicked = { [weak self] in
            self?.closeTranslationPanel()
            self?.showSettingsWindow()
        }
        panel.configure(
            sourceText: sourceText,
            translatedText: nil,
            isLoading: true
        )
        panel.position(at: point)
        panel.orderFrontRegardless()
        translationPanel = panel
    }

    @MainActor
    private func updateTranslationPanel(with result: TranslationResult, sourceText: String) {
        translationPanel?.configure(
            sourceText: sourceText,
            translatedText: result.translatedText,
            isLoading: false,
            errorMessage: result.errorMessage
        )
    }

    @MainActor
    func closeTranslationPanel() {
        translationPanel?.orderOut(nil)
        translationPanel = nil
    }

    @MainActor
    func showSettingsWindow() {
        if settingsWindow == nil {
            let viewModel = SettingsViewModel(
                settings: settings,
                hotKeyManager: hotKeyManager,
                accessibilityManager: accessibilityManager
            )
            let view = SettingsView(viewModel: viewModel)
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = LocalizationManager.localized("window.settings_title")
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 520, height: 780))
            window.center()
            settingsWindow = window
        }
        DispatchQueue.main.async {
            self.updateSettingsWindowTitle()
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    private func updateSettingsWindowTitle() {
        settingsWindow?.title = LocalizationManager.localized("window.settings_title")
    }
}
