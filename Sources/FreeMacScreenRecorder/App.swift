import AppKit
import RecorderUI
import SwiftUI

@main
struct FreeMacScreenRecorderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var vm = RecordingViewModel()

    var body: some Scene {
        WindowGroup("Free Mac Screen Recorder") {
            MainView(vm: vm)
                .onAppear {
                    appDelegate.attach(viewModel: vm)
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}   // hide File → New
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let menuBar = MenuBarController()
    private weak var vm: RecordingViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep the app as a regular app *and* show a menu-bar item, so users
        // can quick-toggle from the bar without closing the main window.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    func attach(viewModel: RecordingViewModel) {
        guard self.vm !== viewModel else { return }
        self.vm = viewModel
        menuBar.install(vm: viewModel)
        viewModel.installGlobalHotkeys()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // keep running in the menu bar after the main window closes
    }
}
