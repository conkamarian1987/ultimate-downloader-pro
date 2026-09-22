import SwiftUI
import AppKit
import UserNotifications

@main struct UltimateDownloaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = DownloadStore()
    var body: some Scene {
        WindowGroup {
            StudioView().environmentObject(store)
                .onAppear { delegate.store = store }
        }.defaultSize(width: 1220, height: 820)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("O Ultimate Downloader Pro") { AboutWindow.shared.show() }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) { UNUserNotificationCenter.current().delegate = self }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) { completionHandler([.banner, .list, .sound]) }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true); NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil); NotificationCenter.default.post(name: .init("ShowDownloadQueue"), object: nil) }; completionHandler()
    }
    var store: DownloadStore?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store else { return .terminateNow }
        if store.busy || store.waitingCount > 0 {
            let alert = NSAlert(); alert.messageText = "Ukončit probíhající úlohy?"
            alert.informativeText = "Rozpracované soubory zůstanou na disku. Stahování můžete později spustit znovu z historie."
            alert.addButton(withTitle: "Zůstat v aplikaci"); alert.addButton(withTitle: "Ukončit")
            guard alert.runModal() == .alertSecondButtonReturn else { return .terminateCancel }
        }
        store.stopForQuit(); return .terminateNow
    }
}

