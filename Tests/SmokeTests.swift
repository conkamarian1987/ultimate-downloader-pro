import Foundation
import Darwin

@main struct SmokeTests {
    static func main() throws {
        let good = try DownloadCommand.validatedURLs("https://example.org/a?x=1&y=2\nhttps://example.org/a?x=1&y=2")
        precondition(good.count == 1)
        for bad in ["", "file:///etc/passwd", "--exec=bad", "https://user:pass@example.org", "https://exa mple.org"] {
            do { _ = try DownloadCommand.validatedURLs(bad); fatalError("Accepted bad input: \(bad)") } catch {}
        }
        let folder = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : NSTemporaryDirectory()
        let url = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "http://127.0.0.1:18765/sample.mp4"
        let paths = ToolPaths.current
        guard let yt = paths.downloader, let ff = paths.ffmpeg else { fatalError("Missing tools") }
        for p in DownloadProfile.audio + DownloadProfile.video {
            let job = DownloadJob(url: url, profile: p, playlist: false, folder: folder)
            let args = DownloadCommand.arguments(for: job, ffmpeg: ff)
            precondition(args.suffix(2) == ["--", url])
            if !p.isAudio, let h = p.quality { precondition(args.contains("bv*[height<=\(h)]+ba/b[height<=\(h)]")) }
            let done = DispatchSemaphore(value: 0)
            let process = ProcessRunner()
            process.run(executable: yt, arguments: args, line: { print($0) }, completion: { code, cancelled in
                precondition(code == 0 && !cancelled, "Failed profile: \(p.id), exit \(code)")
                done.signal()
            })
            precondition(done.wait(timeout: .now() + 60) == .success, "Timed out \(p.id)")
            print("PASS profile \(p.id)")
        }
        // Playlist path and flag are tested separately from the single direct-media fixture.
        let playlistJob = DownloadJob(url: url, profile: DownloadProfile.audio[0], playlist: true, folder: folder)
        let a = DownloadCommand.arguments(for: playlistJob, ffmpeg: ff)
        precondition(a.contains("--yes-playlist") && a.contains(where: { $0.hasPrefix("%(playlist_title|Playlist)s/") }))
        let done = DispatchSemaphore(value: 0)
        let child = ProcessRunner()
        child.run(executable: "/bin/sh", arguments: ["-c", "sleep 30 & wait"], line: { _ in }, completion: { _, cancelled in
            precondition(cancelled); done.signal()
        })
        Thread.sleep(forTimeInterval: 0.2); child.cancel()
        precondition(done.wait(timeout: .now() + 5) == .success, "Process-group cancellation failed")
        let failed = DispatchSemaphore(value: 0)
        ProcessRunner().run(executable: "/bin/sh", arguments: ["-c", "exit 7"], line: { _ in }, completion: { code, cancelled in
            precondition(code == 7 && !cancelled); failed.signal()
        })
        precondition(failed.wait(timeout: .now() + 5) == .success)
        print("PASS validation, 13 real conversions, playlist arguments, cancellation, failure status")
    }
}
