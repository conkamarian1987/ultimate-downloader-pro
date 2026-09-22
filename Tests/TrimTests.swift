import Foundation
@main struct TrimTests {
    static func main() async throws {
        let folder = CommandLine.arguments[1]
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        for profile in [DownloadProfile.video[0], DownloadProfile.audio[0]] {
            let job = DownloadJob(url: "http://127.0.0.1:18766/seekable.mp4", profile: profile, playlist: false, folder: folder, trimStart: 0.5, trimEnd: 1.5)
            let decoded = try JSONDecoder().decode(DownloadJob.self, from: JSONEncoder().encode(job))
            precondition(decoded.trimStart == 0.5 && decoded.trimEnd == 1.5)
            let runner = ProcessRunner()
            let code: Int32 = await withCheckedContinuation { continuation in
                runner.run(executable: ToolPaths.current.downloader!, arguments: DownloadCommand.arguments(for: job, ffmpeg: ToolPaths.current.ffmpeg!), line: { print($0) }, completion: { code, _ in continuation.resume(returning: code) })
            }
            precondition(code == 0)
            print("PASS trim download \(profile.format)")
        }
    }
}
