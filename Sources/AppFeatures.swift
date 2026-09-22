import SwiftUI
import AppKit
import UserNotifications

@MainActor final class ClipboardMonitor: ObservableObject {
    @Published var candidate: String?
    private var timer: Timer?
    private var change = 0
    func setEnabled(_ enabled: Bool) {
        timer?.invalidate(); timer = nil; candidate = nil
        guard enabled else { return }
        change = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }
    private func poll() {
        let board = NSPasteboard.general
        guard board.changeCount != change else { return }
        change = board.changeCount; candidate = nil
        guard let text = board.string(forType: .string), text.count < 8192,
              let urls = try? DownloadCommand.validatedURLs(text), urls.count == 1 else { return }
        candidate = urls[0]
    }
    deinit { timer?.invalidate() }
}

@MainActor final class NotificationSettings: ObservableObject {
    @Published var status = "Načítám stav…"
    func refresh() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                switch settings.authorizationStatus {
                case .authorized, .provisional: self.status = "Systémová oznámení jsou povolena."
                case .denied: self.status = "Oznámení jsou zakázaná v Nastavení systému → Oznámení."
                default: self.status = "Povolení oznámení zatím nebylo uděleno."
                }
            }
        }
    }
    func authorize() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            Task { @MainActor in self.refresh() }
        }
    }
    func test() {
        let content = UNMutableNotificationContent()
        content.title = "Ultimate Downloader Pro"
        content.body = "Oznámení fungují. Tady vás upozorníme na dokončení nebo chybu stahování."
        content.sound = .default
        UNUserNotificationCenter.current().add(.init(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}

struct AppPreferencesView: View {
    @AppStorage("clipboardMonitoring") private var clipboard = false
    @AppStorage("notifications") private var notifications = false
    @StateObject private var settings = NotificationSettings()
    @Environment(\.colorScheme) private var scheme
    private var secondaryText: Color { scheme == .dark ? Color.white.opacity(0.70) : Color(red:0.24,green:0.27,blue:0.30) }
    var body: some View {
        GroupBox("Schránka a oznámení") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Monitorovat odkazy ve schránce", isOn: $clipboard)
                Text("Během běhu aplikace nabídne nově zkopírovaný odkaz. Stažení spustíte sami. Vypnutý monitoring schránku nečte.").font(.caption).foregroundStyle(secondaryText)
                Divider()
                Toggle("Oznámit dokončení a chyby stahování", isOn: $notifications)
                    .onChange(of: notifications) { _, enabled in if enabled { settings.authorize() } }
                Text(settings.status).font(.caption).foregroundStyle(secondaryText)
                HStack {
                    Button("Povolit v systému") { settings.authorize() }
                    Button("Zkušební oznámení") { settings.test() }.disabled(!notifications)
                    Button("Nastavení systému") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!) }
                }
            }.padding(12)
        }.onAppear { settings.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in settings.refresh() }
    }
}

struct DeveloperInfoView: View {
    var body: some View {
        VStack(spacing: 12) {
            if let url = Bundle.main.url(forResource: "DeveloperPhoto", withExtension: "jpg"), let photo = NSImage(contentsOf: url) {
                Image(nsImage: photo).resizable().scaledToFill().frame(width: 100, height: 100).clipShape(Circle())
            }
            Text("Ultimate Downloader Pro · Beta 0.3.1").font(.title3.bold())
            Text("Vývojář: Marian Čonka")
            Link("GitHub: conkamarian1987", destination: URL(string: "https://github.com/conkamarian1987")!)
        }.frame(maxWidth: .infinity).padding(20).tint(.teal)
    }
}
@MainActor final class AboutWindow {
    static let shared = AboutWindow()
    private var window: NSWindow?
    func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 430, height: 320), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "O aplikaci Ultimate Downloader Pro"
            w.contentView = NSHostingView(rootView: DeveloperInfoView())
            w.isReleasedWhenClosed = false; w.center(); window = w
        }
        NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil)
    }
}

struct SavedMediaPreset: Codable, Identifiable {
    var id = UUID()
    var name: String
    var output: String
    var profileID: String
    var container: String
    var imageFormat: String
    var dimension: Int
}
