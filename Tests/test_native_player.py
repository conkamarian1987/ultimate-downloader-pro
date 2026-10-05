#!/usr/bin/env python3
"""Decode a caller-supplied 15s MKV with two audio tracks and an SRT track using the actual model."""
import pathlib, subprocess, sys, tempfile
root = pathlib.Path(__file__).resolve().parents[1]
model = (root / 'Sources/NativeVideoPlayer.swift').read_text().split('private final class VideoFullscreenWindow')[0]
# Software decode test; no claim of on-screen output in a sandboxed shell.
model = model.replace('["--no-video-title-show", "--network-caching=1500"]', '["--no-video-title-show", "--vout=dummy", "--aout=dummy"]')
harness = r'''
// Fullscreen UI is verified in the app, separate from this software decode test.
private class VideoFullscreenWindow: NSWindow { var exit: (() -> Void)?; var activity: (() -> Void)? }
struct NativePlayerView: View { let player: NativeVideoPlayer; var fullscreenMode = false; var body: some View { EmptyView() } }

@main struct Verify {
    @MainActor static func main() throws {
        func pump(_ seconds: Double) { let end = Date().addingTimeInterval(seconds); while Date() < end { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) } }
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory); application.finishLaunching()
        let player = NativeVideoPlayer()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 360), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = player.videoView
        window.orderFront(nil)
        player.volume = 0
        player.play(URL(fileURLWithPath: CommandLine.arguments[1]), title: "Test")
        pump(5)
        guard let stats = player.engine.media?.statistics else { fatalError("No stats") }
        fputs("state=\(player.engine.state.rawValue) video=\(stats.decodedVideo) displayed=\(stats.displayedPictures) audio=\(stats.decodedAudio)\n", stderr)
        precondition(stats.decodedVideo > 0, "Video did not decode")
        precondition(stats.decodedAudio > 0, "Audio did not decode")
        let audio = player.audioTracks.filter { $0.id != -1 }
        precondition(audio.count == 2, "Missing two audio tracks")
        player.chooseAudio(audio[1].id)
        precondition(player.engine.currentAudioTrackIndex == audio[1].id)
        guard let sub = player.subtitleTracks.first(where: { $0.id != -1 }) else { fatalError("Missing subtitle") }
        player.chooseSubtitle(sub.id); precondition(player.engine.currentVideoSubTitleIndex == sub.id)
        player.chooseSubtitle(-1); precondition(player.engine.currentVideoSubTitleIndex == -1)
        player.ratio = "4:3"
        precondition(String(cString: player.engine.videoAspectRatio!) == "4:3")
        player.audioDelay = 0.5; player.subtitleDelay = -0.3
        precondition(player.engine.currentAudioPlaybackDelay == 500000)
        precondition(player.engine.currentVideoSubTitleDelay == -300000)
        player.seek(0.5)
        pump(1)
        precondition(player.engine.time.intValue >= 7000, "Seek failed")
        player.reset()
        precondition(player.engine.currentAudioPlaybackDelay == 0 && player.engine.currentVideoSubTitleDelay == 0)
        print("PASS decodedVideo=\(stats.decodedVideo) displayed=\(stats.displayedPictures) decodedAudio=\(stats.decodedAudio); two audio tracks, subtitles on/off, aspect, timing, seek and reset")
        player.stop(); window.orderOut(nil)
    }
}
'''
with tempfile.TemporaryDirectory(prefix='udp-player-') as tmp:
    source = pathlib.Path(tmp) / 'Check.swift'; binary = pathlib.Path(tmp) / 'MacOS' / 'check'
    binary.parent.mkdir(); (pathlib.Path(tmp) / 'Frameworks').symlink_to(root / 'Frameworks')
    source.write_text(model + harness)
    subprocess.run(['xcrun','swiftc','-parse-as-library','-module-cache-path','/tmp/udp-vlc-module-cache','-F',str(root/'Frameworks'),'-framework','VLCKit','-Xlinker','-rpath','-Xlinker',str(root/'Frameworks'),str(source),'-o',str(binary)],check=True)
    subprocess.run([str(binary),str(pathlib.Path(sys.argv[1]).resolve())],check=True,timeout=25)
