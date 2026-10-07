import SwiftUI
import AppKit
import VLCKit
import UniformTypeIdentifiers
import IOKit.pwr_mgt

final class DisplayWakeLock {
    private var assertion: IOPMAssertionID = 0
    private(set) var active = false
    func setActive(_ enabled: Bool) {
        guard enabled != active else { return }
        if enabled {
            let result = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), "Encore – přehrávání videa" as CFString, &assertion)
            active = result == kIOReturnSuccess
        } else {
            IOPMAssertionRelease(assertion); active = false; assertion = 0
        }
    }
    deinit { if active { IOPMAssertionRelease(assertion) } }
}

struct PlayerTrack: Identifiable { let id: Int32; let name: String }
@MainActor final class NativeVideoPlayer: ObservableObject {
    let engine = VLCMediaPlayer(options: ["--no-video-title-show", "--network-caching=1500"])
    let videoView = VLCVideoView(frame: .zero)
    @Published var isFullscreen = false
    @Published var fullscreenControlsVisible = true
    var controlsInteraction = false
    private var lastInteraction = ProcessInfo.processInfo.systemUptime
    private let displayWakeLock = DisplayWakeLock()
    private var fullscreenWindow: VideoFullscreenWindow?
    @Published var title = ""
    @Published var status = ""
    @Published var playing = false
    @Published var position: Double = 0
    @Published var elapsed = "00:00"
    @Published var duration = "00:00"
    @Published var seekable = false
    @Published var audioTracks: [PlayerTrack] = []
    @Published var subtitleTracks: [PlayerTrack] = []
    @Published var audioIndex: Int32 = -1
    @Published var subtitleIndex: Int32 = -1
    @Published var volume: Double = 80 { didSet { engine.audio?.volume = Int32(volume) } }
    @Published var ratio = "Původní" { didSet { applyPicture() } }
    @Published var display = "Přizpůsobit" { didSet { applyPicture() } }
    @Published var customRatio = "16:9" { didSet { applyPicture() } }
    @Published var zoom: Double = 1 { didSet { applyPicture() } }
    @Published var audioDelay: Double = 0 { didSet { engine.currentAudioPlaybackDelay = Int(audioDelay * 1_000_000) } }
    @Published var subtitleDelay: Double = 0 { didSet { engine.currentVideoSubTitleDelay = Int(subtitleDelay * 1_000_000) } }
    private var timer: Timer?
    private var appliedPicture = ""
    init() { videoView.backColor = .black; engine.drawable = videoView }
    func play(_ url: URL, title: String) {
        stop(); self.title = title; status = "Načítám video…"
        appliedPicture = ""
        engine.media = VLCMedia(url: url); engine.audio?.volume = Int32(volume)
        engine.play()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    func stop() { closeFullscreen(); timer?.invalidate(); timer = nil; engine.stop(); playing = false; title = ""; status = ""; position = 0; audioTracks = []; subtitleTracks = []; seekable = false }
    func toggle() {
        let pausing = engine.isPlaying
        if pausing { engine.pause() } else { engine.play() }
        displayWakeLock.setActive(isFullscreen && !pausing)
        userActivity()
    }
    func userActivity() {
        lastInteraction = ProcessInfo.processInfo.systemUptime
        fullscreenControlsVisible = true
        NSCursor.setHiddenUntilMouseMoves(false)
    }
    private func updateFullscreenState() {
        displayWakeLock.setActive(isFullscreen && engine.isPlaying)
        guard isFullscreen else { return }
        let shouldHide = engine.isPlaying && !controlsInteraction && fullscreenWindow?.isKeyWindow == true
            && fullscreenWindow?.frame.contains(NSEvent.mouseLocation) == true
            && ProcessInfo.processInfo.systemUptime - lastInteraction >= 3
        if fullscreenControlsVisible == shouldHide {
            fullscreenControlsVisible = !shouldHide
            NSCursor.setHiddenUntilMouseMoves(shouldHide)
        }
    }
    func seek(_ value: Double) { if engine.isSeekable { engine.position = Float(value) }; position = value }
    func fullscreen() {
        if isFullscreen { closeFullscreen(); return }
        guard let screen = videoView.window?.screen ?? NSScreen.main else { return }
        let window = VideoFullscreenWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.backgroundColor = .black
        window.isReleasedWhenClosed = false
        window.level = .mainMenu + 1
        window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        window.exit = { [weak self] in self?.closeFullscreen() }
        window.activity = { [weak self] in self?.userActivity() }
        window.acceptsMouseMovedEvents = true
        isFullscreen = true
        userActivity()
        displayWakeLock.setActive(engine.isPlaying)
        window.contentView = NSHostingView(rootView: NativePlayerView(player: self, fullscreenMode: true).background(Color.black).preferredColorScheme(.dark))
        fullscreenWindow = window
        window.makeKeyAndOrderFront(nil)
    }
    func closeFullscreen() {
        guard isFullscreen else { return }
        isFullscreen = false
        displayWakeLock.setActive(false)
        userActivity()
        controlsInteraction = false
        fullscreenWindow?.orderOut(nil)
        fullscreenWindow?.contentView = nil
        fullscreenWindow = nil
    }
    func chooseAudio(_ id: Int32) { engine.currentAudioTrackIndex = id; audioIndex = id }
    func chooseSubtitle(_ id: Int32) { engine.currentVideoSubTitleIndex = id; subtitleIndex = id }
    func addSubtitles() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = false
        if let window = fullscreenWindow { panel.level = NSWindow.Level(rawValue: window.level.rawValue + 1) }
        panel.allowedContentTypes = ["srt", "ass", "ssa", "vtt", "sub"].compactMap { UTType(filenameExtension: $0) }
        if panel.runModal() == .OK, let url = panel.url {
            if engine.addPlaybackSlave(url, type: .subtitle, enforce: true) != 0 { status = "Titulky se nepodařilo přidat." }
        }
    }
    func reset() { ratio = "Původní"; display = "Přizpůsobit"; customRatio = "16:9"; zoom = 1; audioDelay = 0; subtitleDelay = 0 }
    private func tracks(_ ids: [Any], _ names: [Any]) -> [PlayerTrack] {
        zip(ids, names).compactMap { id, name in
            guard let number = id as? NSNumber, let text = name as? String else { return nil }
            return PlayerTrack(id: number.int32Value, name: number.int32Value == -1 ? "Vypnuto" : text)
        }
    }
    private func refresh() {
        updateFullscreenState()
        playing = engine.isPlaying; position = Double(engine.position); seekable = engine.isSeekable
        elapsed = engine.time.stringValue; duration = engine.media?.length.stringValue ?? "00:00"
        audioTracks = tracks(engine.audioTrackIndexes, engine.audioTrackNames)
        subtitleTracks = tracks(engine.videoSubTitlesIndexes, engine.videoSubTitlesNames)
        audioIndex = engine.currentAudioTrackIndex; subtitleIndex = engine.currentVideoSubTitleIndex
        switch engine.state {
        case .error: status = "Video se nepodařilo přehrát. Zkuste jinou kvalitu nebo znovu načtěte video."
        case .opening, .buffering: status = "Načítám video…"
        case .ended: status = "Přehrávání skončilo."
        case .playing, .paused: status = ""
        default: break
        }
        applyPicture()
    }
    private func applyPicture() {
        var value: String?
        if display == "Roztáhnout", videoView.bounds.height > 0 { value = "\(Int(videoView.bounds.width * 100)): \(Int(videoView.bounds.height * 100))".replacingOccurrences(of: " ", with: "") }
        else if ratio != "Původní" {
            let candidate = ratio == "Vlastní" ? customRatio : ratio
            let parts = candidate.split(separator: ":").compactMap { Double($0) }
            if parts.count == 2, parts.allSatisfy({ $0.isFinite && $0 > 0 && $0 < 10000 }) { value = candidate }
        }
        let signature = "\(value ?? "auto")|\(display)|\(zoom)|\(engine.hasVideoOut)"
        guard signature != appliedPicture else { return }; appliedPicture = signature
        if let value { value.withCString { engine.videoAspectRatio = UnsafeMutablePointer(mutating: $0) } }
        else { engine.videoAspectRatio = nil }
        videoView.fillScreen = display == "Vyplnit / oříznout"
        engine.scaleFactor = zoom == 1 ? 0 : Float(zoom)
    }
}
private final class VideoFullscreenWindow: NSWindow {
    var exit: (() -> Void)?
    var activity: (() -> Void)?
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .mouseMoved, .leftMouseDown, .rightMouseDown, .leftMouseDragged, .rightMouseDragged, .scrollWheel, .keyDown: activity?()
        default: break
        }
        super.sendEvent(event)
    }
    override func resignKey() { activity?(); super.resignKey() }
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { exit?() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { exit?() } else { super.keyDown(with: event) }
    }
}
private struct VLCOutput: NSViewRepresentable {
    let player: NativeVideoPlayer
    let fullscreenMode: Bool
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ host: NSView, context: Context) {
        guard player.isFullscreen == fullscreenMode else { return }
        let video = player.videoView
        if video.superview !== host {
            video.removeFromSuperview()
            video.frame = host.bounds; video.autoresizingMask = [.width, .height]
            host.addSubview(video)
        }
    }
}
struct NativePlayerView: View {
    @ObservedObject var player: NativeVideoPlayer
    var fullscreenMode = false
    @State private var showOptions = false
    var body: some View {
        Group {
            if fullscreenMode {
                ZStack {
                    Color.black
                    VLCOutput(player: player, fullscreenMode: true).frame(maxWidth: .infinity, maxHeight: .infinity)
                    VStack {
                        header.padding().background(.black.opacity(0.65))
                        Spacer()
                        VStack(spacing: 8) {
                            if !player.status.isEmpty { Text(player.status).font(.caption) }
                            controls
                        }.padding().background(.black.opacity(0.7))
                    }
                    .opacity(player.fullscreenControlsVisible ? 1 : 0)
                    .allowsHitTesting(player.fullscreenControlsVisible)
                    .animation(.easeInOut(duration: 0.2), value: player.fullscreenControlsVisible)
                }
            } else {
                VStack(spacing: 10) {
                    header
                    if player.isFullscreen {
                        Button("Vrátit video z celé obrazovky") { player.closeFullscreen() }.frame(height: 240)
                    } else {
                        VLCOutput(player: player, fullscreenMode: false).frame(minHeight: 240, idealHeight: 330, maxHeight: 450).background(.black).clipShape(RoundedRectangle(cornerRadius:12))
                    }
                    if !player.status.isEmpty { Text(player.status).font(.caption).foregroundStyle(.secondary) }
                    controls
                }
            }
        }
        .buttonStyle(StudioButtonStyle())
        .onChange(of: showOptions) { _, value in player.controlsInteraction = value; player.userActivity() }
    }
    private var header: some View {
        HStack { Text(player.title).font(.headline).lineLimit(1); Spacer(); Button("Zavřít přehrávač") { player.stop() } }
    }
    private var controls: some View {
            HStack {
                Button { player.toggle() } label: { Image(systemName: player.playing ? "pause.fill" : "play.fill") }.help("Přehrát / pozastavit")
                Text(player.elapsed).monospacedDigit().font(.caption)
                Slider(value: Binding(get: { player.position }, set: { player.seek($0) }), in: 0...1).disabled(!player.seekable).accessibilityLabel("Pozice přehrávání")
                Text(player.duration).monospacedDigit().font(.caption)
                Image(systemName: "speaker.wave.2")
                Slider(value: $player.volume, in: 0...100).frame(width: 90).accessibilityLabel("Hlasitost")
                Button("Obraz a zvuk", systemImage: "slider.horizontal.3") { showOptions.toggle() }.popover(isPresented: $showOptions) { options.padding(20).frame(width: 410) }
                Button { player.fullscreen() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.help(fullscreenMode ? "Ukončit celou obrazovku (Esc)" : "Video na celou obrazovku")
            }
    }
    private var options: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Obraz a zvuk").font(.headline)
            Picker("Poměr stran", selection: $player.ratio) { ForEach(["Původní", "16:9", "4:3", "21:9", "Vlastní"], id: \.self) { Text($0) } }
            if player.ratio == "Vlastní" { TextField("Vlastní poměr, např. 16:10", text: $player.customRatio) }
            Picker("Zobrazení", selection: $player.display) { ForEach(["Přizpůsobit", "Vyplnit / oříznout", "Roztáhnout"], id: \.self) { Text($0) } }
            HStack { Text("Přiblížení"); Slider(value: $player.zoom, in: 1...3, step: 0.1); Text(String(format: "%.1f×", player.zoom)).monospacedDigit() }
            Divider()
            Picker("Zvuková stopa", selection: Binding(get: { player.audioIndex }, set: { player.chooseAudio($0) })) {
                ForEach(player.audioTracks) { Text($0.name).tag($0.id) }
            }.disabled(player.audioTracks.isEmpty)
            Picker("Titulky", selection: Binding(get: { player.subtitleIndex }, set: { player.chooseSubtitle($0) })) {
                Text("Vypnuto").tag(Int32(-1))
                ForEach(player.subtitleTracks.filter { $0.id != -1 }) { Text($0.name).tag($0.id) }
            }
            Button("Načíst titulky ze souboru…") { player.addSubtitles() }
            Stepper(value: $player.audioDelay, in: -30...30, step: 0.1) { Text(String(format: "Posun zvuku: %+.1f s", player.audioDelay)) }
            Stepper(value: $player.subtitleDelay, in: -60...60, step: 0.1) { Text(String(format: "Posun titulků: %+.1f s", player.subtitleDelay)) }
            Text("Kladný posun zvuk nebo titulky zpozdí.").font(.caption).foregroundStyle(.secondary)
            Button("Obnovit obraz a časování") { player.reset() }
        }
    }
}
