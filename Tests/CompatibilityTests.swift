import Foundation
import AVFoundation

// DownloadJob's unrelated image option payload is not exercised by this executable.
struct ImageOptions: Codable {}

final class ProgressEvents: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [AppleVideoCompatibility.Progress] = []
    func append(_ value: AppleVideoCompatibility.Progress) { lock.lock(); defer { lock.unlock() }; values.append(value) }
    func verify() {
        lock.lock(); defer { lock.unlock() }
        precondition(values.contains { if case .checking = $0 { return true }; return false })
        precondition(values.contains { if case .converting(let value) = $0, let value { return value > 0 && value < 1 }; return false })
        precondition(values.contains { if case .finalizing = $0 { return true }; return false })
    }
}

@main struct CompatibilityTests {
    static func main() async throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let ff = ToolPaths.current.ffmpeg!, probe = ToolPaths.current.ffprobe!
        let original = root.appendingPathComponent("vp9-opus.mp4")
        let fixture = try Data(contentsOf: original)
        for name in ["vp9-opus.mp4", "h264-aac.mp4"] {
            let path = root.appendingPathComponent(name).path
            let before = try Data(contentsOf: URL(fileURLWithPath: path))
            let events = ProgressEvents()
            let filesBefore = Set(try FileManager.default.contentsOfDirectory(atPath: root.path))
            try await AppleVideoCompatibility.prepare(path, ffmpeg: ff, ffprobe: probe, runner: ProcessRunner(), progress: { events.append($0) }, line: { print($0) })
            let result = try await AppleVideoCompatibility.probe(path, executable: probe, runner: ProcessRunner())
            precondition(result.compatible)
            let filesAfter = Set(try FileManager.default.contentsOfDirectory(atPath: root.path))
            precondition(filesBefore == filesAfter)
            if name == "vp9-opus.mp4" { events.verify(); print("PASS progress: checking, conversion percentage, finalizing; only one output file") }
            if name == "h264-aac.mp4" { let after = try Data(contentsOf: URL(fileURLWithPath: path)); precondition(before == after) }
            let asset = AVURLAsset(url: URL(fileURLWithPath: path))
            let reader = try AVAssetReader(asset: asset)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            let output = AVAssetReaderTrackOutput(track: tracks[0], outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
            reader.add(output)
            guard reader.startReading() else { throw reader.error ?? NSError(domain: "Reader", code: 1) }
            var frames = 0
            while let sample = output.copyNextSampleBuffer() { precondition(CMSampleBufferGetImageBuffer(sample) != nil); frames += 1 }
            precondition(reader.status == .completed && frames >= 40, "Apple failed to decode video: \(String(describing: reader.error))")
            print("PASS \(name): H.264/AAC; Apple decoded \(frames) video frames")
        }
        for mode in ["failure", "cancel", "cancel-during"] {
            let path = root.appendingPathComponent("\(mode).mp4")
            try fixture.write(to: path)
            let runner = ProcessRunner()
            if mode == "cancel" { runner.cancel() }
            do {
                try await AppleVideoCompatibility.prepare(path.path, ffmpeg: mode == "cancel-during" ? ff : "/usr/bin/false", ffprobe: probe, runner: runner, progress: { value in
                    if mode == "cancel-during", case .converting(let fraction) = value, let fraction, fraction > 0 { runner.cancel() }
                }, line: { print($0) })
                fatalError("Expected failure")
            } catch {
                let after = try Data(contentsOf: path)
                precondition(after == fixture)
                if mode.hasPrefix("cancel") { precondition(error is CancellationError) }
                let remaining = try FileManager.default.contentsOfDirectory(atPath: root.path)
                precondition(!remaining.contains { $0.hasPrefix(".udp-") })
                print("PASS \(mode): original preserved, temporary output removed")
            }
        }
    }
}
