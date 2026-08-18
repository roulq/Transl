import SwiftUI
import AppKit
import Combine
import Carbon.HIToolbox

@MainActor
final class SettingsViewModel: ObservableObject {
    let settings: AppSettings
    let hotKeyManager: HotKeyManager
    let accessibilityManager: AccessibilityManager

    @Published var hotKeyCombo: KeyCombo
    @Published var targetLanguageCode: String
    @Published var fallbackLanguageCode: String
    @Published var appLanguage: String
    @Published var autoCopyResult: Bool
    @Published var launchAtLogin: Bool
    @Published var accessibilityGranted: Bool
    @Published var availableLanguages: [LanguageOption]
    let appVersion: String

    private var settingsTimer: Timer?

    init(
        settings: AppSettings,
        hotKeyManager: HotKeyManager,
        accessibilityManager: AccessibilityManager
    ) {
        self.settings = settings
        self.hotKeyManager = hotKeyManager
        self.accessibilityManager = accessibilityManager
        self.hotKeyCombo = settings.hotKeyCombo
        self.targetLanguageCode = settings.targetLanguageCode
        self.fallbackLanguageCode = settings.fallbackLanguageCode
        self.appLanguage = settings.appLanguage
        self.autoCopyResult = settings.autoCopyResult
        self.launchAtLogin = settings.launchAtLogin
        self.accessibilityGranted = accessibilityManager.isPermissionGranted
        self.availableLanguages = TranslationService.availableLanguages
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        settingsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self, accessibilityManager] _ in
            Task { @MainActor in self?.accessibilityGranted = accessibilityManager.isPermissionGranted }
        }
    }

    deinit {
        settingsTimer?.invalidate()
    }

    func commitHotKey(_ combo: KeyCombo) {
        hotKeyCombo = combo
        settings.hotKeyCombo = combo
        hotKeyManager.update(keyCombo: combo)
    }

    func commitTargetLanguage(_ code: String) {
        targetLanguageCode = code
        settings.targetLanguageCode = code
    }

    func commitFallbackLanguage(_ code: String) {
        fallbackLanguageCode = code
        settings.fallbackLanguageCode = code
    }

    func commitAppLanguage(_ code: String) {
        appLanguage = code
        settings.appLanguage = code
        LocalizationManager.shared.currentLanguage = code
    }

    func toggleAutoCopy(_ value: Bool) {
        autoCopyResult = value
        settings.autoCopyResult = value
    }

    func toggleLaunchAtLogin(_ value: Bool) {
        settings.launchAtLogin = value
        launchAtLogin = settings.launchAtLogin
    }

    func requestAccessibility() {
        accessibilityManager.requestPermission()
        accessibilityGranted = accessibilityManager.isPermissionGranted
    }

    func openAccessibilitySettings() {
        accessibilityManager.openAccessibilitySettings()
    }
}

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel
    @ObservedObject var localizationManager = LocalizationManager.shared
    @State private var cmdCommaMonitor: Any?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                hotKeySection
                Divider()
                languageSection
                Divider()
                fallbackLanguageSection
                Divider()
                appLanguageSection
                Divider()
                togglesSection
                Divider()
                accessibilitySection
                Divider()
                aboutSection
            }
            .padding(24)
        }
        .frame(width: 520, height: 780)
        .id(localizationManager.currentLanguage)
        .onAppear { installCmdCommaMonitor() }
        .onDisappear { removeCmdCommaMonitor() }
    }

    private var hotKeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(LocalizationManager.localized("settings.global_hotkey"), systemImage: "keyboard")
                .font(.system(size: 14, weight: .semibold))

            HStack(spacing: 6) {
                HotKeyRecorderView(
                    currentCombo: $viewModel.hotKeyCombo,
                    onRecorded: { combo in viewModel.commitHotKey(combo) }
                )
                .frame(width: 220, height: 36)

                Button {
                    viewModel.commitHotKey(.defaultOptionT)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(width: 28, height: 28)
                .clipShape(Rectangle())
                .help(LocalizationManager.localized("settings.reset_hint"))
            }

            Text(LocalizationManager.localized("settings.hotkey_hint"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(LocalizationManager.localized("settings.target_language"), systemImage: "globe")
                .font(.system(size: 14, weight: .semibold))

            HStack {
                Picker("", selection: Binding(
                    get: { viewModel.targetLanguageCode },
                    set: { viewModel.commitTargetLanguage($0) }
                )) {
                    ForEach(viewModel.availableLanguages) { lang in
                        Text(LocalizationManager.localized("lang.\(lang.code)")).tag(lang.code)
                    }
                }
                .labelsHidden()
                .frame(width: 240, alignment: .leading)
                .id(localizationManager.currentLanguage)

                Spacer()
            }

            Text(LocalizationManager.localized("settings.target_language_hint"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var fallbackLanguageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(LocalizationManager.localized("settings.fallback_language"), systemImage: "arrow.triangle.2.circlepath")
                .font(.system(size: 14, weight: .semibold))

            HStack {
                Picker("", selection: Binding(
                    get: { viewModel.fallbackLanguageCode },
                    set: { viewModel.commitFallbackLanguage($0) }
                )) {
                    ForEach(viewModel.availableLanguages) { lang in
                        Text(LocalizationManager.localized("lang.\(lang.code)")).tag(lang.code)
                    }
                }
                .labelsHidden()
                .frame(width: 240, alignment: .leading)
                .id(localizationManager.currentLanguage)

                Spacer()
            }

            Text(LocalizationManager.localized("settings.fallback_language_hint"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var appLanguageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(LocalizationManager.localized("settings.app_language"), systemImage: "globe")
                .font(.system(size: 14, weight: .semibold))

            HStack {
                Picker("", selection: Binding(
                    get: { viewModel.appLanguage },
                    set: { viewModel.commitAppLanguage($0) }
                )) {
                    Text("English").tag("en")
                    Text("Русский").tag("ru")
                    Text("Deutsch").tag("de")
                    Text("Polski").tag("pl")
                    Text("Español").tag("es")
                    Text("Italiano").tag("it")
                    Text("Français").tag("fr")
                    Text("日本語").tag("ja")
                    Text("中文 (简体)").tag("zh-CN")
                    Text("Português").tag("pt")
                    Text("Nederlands").tag("nl")
                }
                .labelsHidden()
                .frame(width: 240, alignment: .leading)

                Spacer()
            }

            Text(LocalizationManager.localized("settings.app_language_hint"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var togglesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(LocalizationManager.localized("settings.general"), systemImage: "gearshape")
                .font(.system(size: 14, weight: .semibold))

            Toggle(isOn: Binding(
                get: { viewModel.autoCopyResult },
                set: { viewModel.toggleAutoCopy($0) }
            )) {
                Text(LocalizationManager.localized("settings.auto_copy"))
                    .font(.system(size: 13))
            }
            .toggleStyle(.switch)

            Toggle(isOn: Binding(
                get: { viewModel.launchAtLogin },
                set: { viewModel.toggleLaunchAtLogin($0) }
            )) {
                Text(LocalizationManager.localized("settings.launch_at_login"))
                    .font(.system(size: 13))
            }
            .toggleStyle(.switch)
        }
    }

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(LocalizationManager.localized("settings.accessibility"), systemImage: "hand.raised.fill")
                .font(.system(size: 14, weight: .semibold))

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.accessibilityGranted ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(viewModel.accessibilityGranted ? LocalizationManager.localized("settings.allowed") : LocalizationManager.localized("settings.no_access"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(viewModel.accessibilityGranted ? .green : .red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(viewModel.accessibilityGranted ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                )

                Button(LocalizationManager.localized("settings.request_rights")) {
                    viewModel.requestAccessibility()
                }
                .controlSize(.small)

                Button(LocalizationManager.localized("settings.open_system_settings")) {
                    viewModel.openAccessibilitySettings()
                }
                .controlSize(.small)

                Spacer()
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(LocalizationManager.localized("about.title"), systemImage: "info.circle")
                .font(.system(size: 14, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizationManager.localized("about.description"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)

                HStack(spacing: 4) {
                    Text(LocalizationManager.localized("about.developer"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(LocalizationManager.localized("about.version"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(viewModel.appVersion)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Link(destination: URL(string: "https://discord.gg/SPM8Fj4xsh")!) {
                    Text(LocalizationManager.localized("about.discord"))
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                }
            }
        }
    }

    private func installCmdCommaMonitor() {
        removeCmdCommaMonitor()
        cmdCommaMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.keyCode == kVK_ANSI_Comma {
                NSApp.keyWindow?.close()
                return nil
            }
            return event
        }
    }

    private func removeCmdCommaMonitor() {
        if let monitor = cmdCommaMonitor {
            NSEvent.removeMonitor(monitor)
            cmdCommaMonitor = nil
        }
    }
}

private struct HotKeyRecorderView: NSViewRepresentable {
    @Binding var currentCombo: KeyCombo
    var onRecorded: (KeyCombo) -> Void

    func makeNSView(context: Context) -> HotKeyRecorder {
        let v = HotKeyRecorder()
        v.currentCombo = currentCombo
        v.onRecorded = { combo in
            currentCombo = combo
            onRecorded(combo)
        }
        return v
    }

    func updateNSView(_ nsView: HotKeyRecorder, context: Context) {
        nsView.currentCombo = currentCombo
    }
}
