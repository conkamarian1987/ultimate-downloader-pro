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
            Text("Ultimate Downloader Pro · Beta \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))").font(.title3.bold())
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

import Sparkle
import Combine

/// Keeps installation out of the download queue, including a paused queue.
@MainActor final class AppUpdates: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var canCheck = false
    @Published private(set) var status = ""
    @Published var automaticChecks = true {
        didSet { if controller != nil { controller.updater.automaticallyChecksForUpdates = automaticChecks } }
    }
    @Published var automaticDownloads = true {
        didSet { if controller != nil { controller.updater.automaticallyDownloadsUpdates = automaticDownloads } }
    }
    private var controller: SPUStandardUpdaterController!
    private var observation: AnyCancellable?
    private weak var store: DownloadStore?
    private var deferredInstall: (() -> Void)?
    private var waitTask: Task<Void, Never>?
    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        observation = controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main).sink { [weak self] in self?.canCheck = $0 }
        automaticChecks = controller.updater.automaticallyChecksForUpdates
        automaticDownloads = controller.updater.automaticallyDownloadsUpdates
    }
    func connect(to store: DownloadStore) {
        guard self.store == nil else { return }
        self.store = store
        do { try controller.updater.start() }
        catch { status = "Aktualizace nelze spustit: \(error.localizedDescription)" }
    }
    func check() {
        guard canCheck else { return }
        status = ""
        controller.checkForUpdates(nil)
    }
    private var queueIsIdle: Bool {
        guard let store else { return false }
        return !store.busy && store.waitingCount == 0 && !store.mediaPlaybackActive
    }
    private func deferInstallation(_ handler: @escaping () -> Void) {
        deferredInstall = handler
        status = "Aktualizace je připravena. Instalace čeká na dokončení fronty a zavření přehrávače."
        waitTask?.cancel()
        waitTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                if self.queueIsIdle {
                    let install = self.deferredInstall
                    self.deferredInstall = nil
                    self.status = "Instaluji aktualizaci…"
                    self.store?.save()
                    install?()
                    return
                }
            }
        }
    }
    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem,
                 untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        guard !queueIsIdle else { store?.save(); return false }
        deferInstallation(installHandler)
        return true
    }
    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
                 immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        // Always defer one event loop, so the delegate returns before installation starts.
        deferInstallation(immediateInstallHandler)
        return true
    }
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        waitTask?.cancel(); deferredInstall = nil
        status = "Aktualizace nebyla dokončena: \(error.localizedDescription)"
    }
}
