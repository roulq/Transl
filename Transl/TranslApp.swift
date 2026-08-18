import SwiftUI
import AppKit

@main
struct TranslApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("", id: "hidden-root") {
            EmptyView()
                .frame(width: 0, height: 0)
                .hidden()
                .onAppear { NSApp.windows.first?.close() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) { }
            CommandGroup(replacing: .appSettings) {
                Button("Настройки Transl") {
                    AppDelegate.shared?.showSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) { }
        }
    }
}
