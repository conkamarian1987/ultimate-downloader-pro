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
        content.title = "Encore"
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
            Text("Encore · Beta \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))").font(.title3.bold())
            Text("Vývojář: Marian Čonka")
            Link("GitHub: conkamarian1987", destination: URL(string: "https://github.com/conkamarian1987")!)
        }.frame(maxWidth: .infinity).padding(20).tint(.blue)
    }
}
@MainActor final class AboutWindow {
    static let shared = AboutWindow()
    private var window: NSWindow?
    func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 430, height: 320), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "O aplikaci Encore"
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

/// A fresh process must verify the feed. No timer or offline unlock is used.
@MainActor final class AppUpdates: NSObject, ObservableObject, SPUUpdaterDelegate, SPUUserDriver {
    @Published private(set) var unlocked = false
    @Published private(set) var canCheck = false
    @Published private(set) var status = "Ověřuji aktuální verzi…"
    @Published private(set) var canInstall = false
    @Published private(set) var progress: Double?
    private var updater: SPUUpdater!
    private var observation: AnyCancellable?
    private weak var store: DownloadStore?
    private var installReply: ((SPUUserUpdateChoice) -> Void)?
    @Published private(set) var installationReadyToQuit = false
    private var terminationTask: Task<Void, Never>?
    private var requestTermination: () -> Void = { NSApp.terminate(nil) }
    private var expected: UInt64 = 0
    private var received: UInt64 = 0
    override init() {
        super.init()
        updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: self, delegate: self)
        observation = updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main).sink { [weak self] in self?.canCheck = $0 }
    }
    func connect(to store: DownloadStore) {
        guard self.store == nil else { return }
        self.store = store
        // Override existing preferences too, including those saved by older versions.
        updater.automaticallyChecksForUpdates = false
        updater.automaticallyDownloadsUpdates = false
        do { try updater.start(); updater.checkForUpdates() }
        catch { fail(error) }
    }
    func check() {
        guard !unlocked, canCheck else { return }
        status = "Ověřuji aktuální verzi…"; progress = nil
        updater.checkForUpdates()
    }
    func install() {
        guard let reply = installReply else { return }
        installReply = nil; canInstall = false
        status = "Připravuji aktualizaci…"; reply(.install)
    }
    private func fail(_ error: Error) {
        guard !unlocked else { return }
        terminationTask?.cancel(); terminationTask = nil; installationReadyToQuit = false
        canInstall = false; installReply = nil; progress = nil
        status = "Ověření nebo aktualizace se nezdařily. Připojte se k internetu a zkuste to znovu.\n\(error.localizedDescription)"
    }
    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false))
    }
    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        status = "Ověřuji aktuální verzi…"; progress = nil
    }
    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        guard !appcastItem.isInformationOnlyUpdate else {
            status = "Tato aktualizace vyžaduje ruční instalaci. Navštivte stránku projektu na GitHubu."
            reply(.dismiss); return
        }
        status = "Je vyžadována verze \(appcastItem.displayVersionString). Aktualizace nahradí tuto kopii aplikace a zachová nastavení i stažené soubory."
        installReply = reply; canInstall = true
    }
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}
    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        let info = (error as NSError).userInfo
        let reason = (info[SPUNoUpdateFoundReasonKey] as? NSNumber)?.intValue
        if (error as NSError).domain == SUSparkleErrorDomain, (error as NSError).code == 1001,
           (reason == 1 || reason == 2),
           let item = info[SPULatestAppcastItemFoundKey] as? SUAppcastItem,
           let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
           item.versionString.compare(build, options: .numeric) != .orderedDescending {
            unlocked = true; store?.updatesBlocked = false
            status = "Aktuální verze byla ověřena při spuštění."
        } else { fail(error) }
        acknowledgement()
    }
    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) { fail(error); acknowledgement() }
    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        expected = 0; received = 0; progress = nil; status = "Stahuji aktualizaci…"
    }
    func showDownloadDidReceiveExpectedContentLength(_ length: UInt64) { expected = length }
    func showDownloadDidReceiveData(ofLength length: UInt64) {
        received += length
        if expected > 0 { progress = min(1, Double(received) / Double(expected)) }
    }
    func showDownloadDidStartExtractingUpdate() { status = "Ověřuji a rozbaluji aktualizaci…"; progress = nil }
    func showExtractionReceivedProgress(_ value: Double) { progress = value }
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        status = "Aktualizace je ověřená. Připravuji nahrazení aplikace…"
        progress = nil; store?.save()
        // Keep the process alive until Sparkle acknowledges installation stage 2.
        reply(.install)
    }
    func showInstallingUpdate(withApplicationTerminated terminated: Bool, retryTerminatingApplication retry: @escaping () -> Void) {
        progress = nil
        guard !terminated else {
            status = "Instaluji novou verzi…"; return
        }
        guard !installationReadyToQuit else { return }
        // The external Sparkle installer is now ready and survives our exit.
        // Do not rely solely on its Apple quit event reaching the application.
        installationReadyToQuit = true
        status = "Ukončuji původní verzi. Instalátor ji nahradí a spustí novou…"
        store?.save()
        terminationTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard !Task.isCancelled, let self, self.installationReadyToQuit else { return }
            self.requestTermination()
        }
    }
    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) { acknowledgement() }
    func dismissUpdateInstallation() {
        terminationTask?.cancel(); terminationTask = nil; installationReadyToQuit = false
        installReply = nil; canInstall = false; progress = nil
    }
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        // Sparkle also ends a successful no-update cycle with this informational error.
        if (error as NSError).domain == SUSparkleErrorDomain && (error as NSError).code == 1001 { return }
        fail(error)
    }
}

struct RequiredUpdateView: View {
    @EnvironmentObject private var updates: AppUpdates
    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "arrow.down.circle").font(.system(size: 52)).foregroundStyle(.blue)
            Text("Encore").font(.largeTitle.bold())
            Text("Před spuštěním je nutné ověřit aktuální verzi.").font(.title3)
            Text(updates.status).multilineTextAlignment(.center).textSelection(.enabled)
            if let progress = updates.progress { ProgressView(value: progress) }
            else if !updates.canCheck && !updates.canInstall { ProgressView() }
            HStack {
                if updates.canInstall { Button("Aktualizovat a restartovat") { updates.install() }.buttonStyle(.borderedProminent) }
                else { Button("Zkusit znovu") { updates.check() }.disabled(!updates.canCheck) }
                Button("Ukončit") { NSApp.terminate(nil) }.disabled(updates.installationReadyToQuit)
            }
            Text("Kontrola probíhá pouze při spuštění. Bez úspěšného ověření nelze aplikaci používat.").font(.caption).foregroundStyle(.secondary)
        }.padding(48).frame(maxWidth: 680).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
