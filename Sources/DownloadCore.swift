import Foundation

struct DownloadProfile: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let format: String
    let quality: Int?
    let suffix: String
    var isAudio: Bool { ["mp3", "m4a", "flac", "wav", "opus", "ogg"].contains(format) }
    static let audio: [Self] = [
        .init(id: "mp3-320", title: "MP3 · 320 kb/s", format: "mp3", quality: 320, suffix: "320k"),
        .init(id: "mp3-256", title: "MP3 · 256 kb/s", format: "mp3", quality: 256, suffix: "256k"),
        .init(id: "mp3-192", title: "MP3 · 192 kb/s", format: "mp3", quality: 192, suffix: "192k"),
        .init(id: "m4a-256", title: "M4A / AAC · 256 kb/s", format: "m4a", quality: 256, suffix: "M4A 256k"),
        .init(id: "m4a-192", title: "M4A / AAC · 192 kb/s", format: "m4a", quality: 192, suffix: "M4A 192k"),
        .init(id: "flac", title: "FLAC · bezztrátový formát", format: "flac", quality: nil, suffix: "FLAC"),
        .init(id: "wav", title: "WAV · nekomprimovaný", format: "wav", quality: nil, suffix: "WAV")
    ]
    static let video: [Self] = [
        .init(id: "max", title: "MP4 · nejvyšší dostupná kvalita", format: "mp4", quality: nil, suffix: "Max Quality"),
        .init(id: "2160", title: "MP4 · 4K / 2160p", format: "mp4", quality: 2160, suffix: "4K"),
        .init(id: "1440", title: "MP4 · 2K / 1440p", format: "mp4", quality: 1440, suffix: "2K"),
        .init(id: "1080", title: "MP4 · 1080p / Full HD", format: "mp4", quality: 1080, suffix: "1080p"),
        .init(id: "720", title: "MP4 · 720p / HD", format: "mp4", quality: 720, suffix: "720p"),
        .init(id: "480", title: "MP4 · 480p", format: "mp4", quality: 480, suffix: "480p")
    ]
}

enum JobState: String, Codable {
    case queued = "Ve frontě", running = "Stahuje se", finished = "Dokončeno", failed = "Chyba", cancelled = "Zrušeno"
}
struct DownloadJob: Identifiable, Codable {
    var id = UUID()
    let url: String
    let profile: DownloadProfile
    let playlist: Bool
    let folder: String
    var created = Date()
    var state = JobState.queued
    var progress: Double = 0
    var detail = "Čeká na spuštění"
    var files: [String] = []
    var log = ""
    var hellspy: HellspyReference? = nil
    var downloadTotalBytes: Int64? = nil
    var formatSelector: String? = nil
    var subtitleLanguage: String? = nil
    var imageOptions: ImageOptions? = nil
    var displayTitle: String? = nil
    var referer: String? = nil
    var trimStart: Double? = nil
    var trimEnd: Double? = nil
    var conversionStage: String? = nil
    var conversionProgress: Double? = nil
}

enum DownloadCommand {
    static func validatedURLs(_ text: String) throws -> [String] {
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !lines.isEmpty else { throw InputError.invalid("Vložte odkaz na video nebo playlist.") }
        for line in lines {
            guard let url = URLComponents(string: line), ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                  let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
                  !line.contains(where: { $0.isWhitespace }) else {
                throw InputError.invalid("Neplatný odkaz: \(line). Použijte adresu http nebo https, každý odkaz na vlastní řádek.")
            }
        }
        return Array(NSOrderedSet(array: lines)) as? [String] ?? lines
    }
    static func arguments(for job: DownloadJob, ffmpeg: String) -> [String] {
        let p = job.profile
        var args = ["--ignore-config", "--no-simulate", "--newline", "--progress", "--no-colors",
                    "--no-overwrites", "--no-post-overwrites", "--continue", "--windows-filenames",
                    "--ffmpeg-location", ffmpeg, "--embed-metadata",
                    "--progress-template", "download:UDP_PROGRESS|%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
                    "--print", "before_dl:UDP_TITLE|%(title)s",
                    "--print", "after_move:UDP_FILE|%(filepath)j",
                    "-P", job.folder, job.playlist ? "--yes-playlist" : "--no-playlist"]
        // WAV does not support embedded cover art in yt-dlp.
        if p.format != "wav" { args += ["--embed-thumbnail", "--convert-thumbnails", "jpg"] }
        if p.isAudio {
            args += ["-f", "bestaudio/best", "-x", "--audio-format", p.format]
            if let bitrate = p.quality {
                args += ["--audio-quality", "\(bitrate)K"]
                // Force AAC encoding even if the source is already AAC (otherwise it may be copied).
                if p.format == "m4a" {
                    args += ["--postprocessor-args", "ExtractAudio+ffmpeg_o:-c:a aac -b:a \(bitrate)k"]
                }
            }
        } else {
            let selector = job.formatSelector ?? p.quality.map { "bv*[height<=\($0)]+ba/b[height<=\($0)]" } ?? "bv*+ba/b"
            args += ["-f", selector, "--merge-output-format", p.format, "--remux-video", p.format]
        }
        if let referer = job.referer { args += ["--referer", referer] }
        if let lang = job.subtitleLanguage { args += ["--write-subs", "--sub-langs", lang, "--convert-subs", "srt"] }
        var trimSuffix = ""
        if let start = job.trimStart {
            let end = job.trimEnd.map { String($0) } ?? "inf"
            args += ["--download-sections", "*\(start)-\(end)", "--force-keyframes-at-cuts"]
            trimSuffix = " [\(start)-\(end)]"
        }
        let prefix = job.playlist ? "%(playlist_title|Playlist)s/%(playlist_index)03d - " : ""
        args += ["-o", prefix + "%(title)s [\(p.suffix)]" + trimSuffix + ".%(ext)s", "--", job.url]
        return args
    }
    enum InputError: LocalizedError {
        case invalid(String)
        var errorDescription: String? { if case .invalid(let text) = self { return text }; return nil }
    }
}

struct ToolPaths {
    let downloader: String?
    let ffmpeg: String?
    let ffprobe: String?
    let brew: String?
    static func find(_ name: String) -> String? {
        ["/opt/homebrew/bin/", "/usr/local/bin/"].map { $0 + name }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    static var current: Self { .init(downloader: find("yt-dlp"), ffmpeg: find("ffmpeg"), ffprobe: find("ffprobe"), brew: find("brew")) }
    var ready: Bool { downloader != nil && ffmpeg != nil && ffprobe != nil }
}

/// MP4 is a container, not a guarantee that QuickTime can decode its streams.
enum AppleVideoCompatibility {
    enum Progress: Sendable {
        case checking, converting(Double?), finalizing
    }
    struct Probe: Decodable {
        struct Format: Decodable { let duration: String? }
        struct Stream: Decodable {
            let codec_type: String?
            let codec_name: String?
            let pix_fmt: String?
            let disposition: [String: Int]?
        }
        let streams: [Stream]
        let format: Format?
        var duration: Double? {
            guard let text = format?.duration, let value = Double(text), value.isFinite, value > 0 else { return nil }
            return value
        }
        var video: Stream? { streams.first { $0.codec_type == "video" && $0.disposition?["attached_pic"] != 1 } }
        var compatible: Bool {
            guard let video, video.codec_name == "h264", video.pix_fmt == "yuv420p" else { return false }
            return streams.filter { $0.codec_type == "audio" }.allSatisfy { $0.codec_name == "aac" }
        }
    }
    private final class Output: @unchecked Sendable {
        let lock = NSLock()
        var value = ""
        func append(_ line: String) { lock.lock(); defer { lock.unlock() }; value += line + "\n" }
        func read() -> String { lock.lock(); defer { lock.unlock() }; return value }
    }
    static func probe(_ path: String, executable: String, runner: ProcessRunner) async throws -> Probe {
        let output = Output()
        let result: (Int32, Bool) = await withCheckedContinuation { continuation in
            runner.run(executable: executable, arguments: ["-v", "error", "-show_streams", "-show_format", "-of", "json", path],
                       line: { output.append($0) }, completion: { continuation.resume(returning: ($0, $1)) })
        }
        if result.1 { throw CancellationError() }
        guard result.0 == 0, let data = output.read().data(using: .utf8),
              let probe = try? JSONDecoder().decode(Probe.self, from: data), probe.video != nil else {
            throw DownloadCommand.InputError.invalid("Nelze ověřit obrazovou stopu: \(URL(fileURLWithPath: path).lastPathComponent)")
        }
        return probe
    }
    static func prepare(_ path: String, ffmpeg: String, ffprobe: String, runner: ProcessRunner,
                        progress: @escaping @Sendable (Progress) -> Void = { _ in },
                        line: @escaping @Sendable (String) -> Void) async throws {
        progress(.checking)
        let source = try await probe(path, executable: ffprobe, runner: runner)
        guard !source.compatible else { return }
        let original = URL(fileURLWithPath: path)
        let temporary = original.deletingLastPathComponent().appendingPathComponent(".udp-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: temporary) }
        var args = ["-nostdin", "-hide_banner", "-v", "warning", "-nostats", "-progress", "pipe:1", "-stats_period", "0.5", "-n", "-i", path,
                    "-map", "0:V:0", "-map", "0:a:0?", "-map_metadata", "0"]
        if source.video?.codec_name == "h264" && source.video?.pix_fmt == "yuv420p" {
            args += ["-c:v", "copy"]
        } else {
            args += ["-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p",
                     "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2"]
        }
        args += ["-tag:v", "avc1", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", temporary.path]
        line("Převádím MP4 pro přehrávač Apple (H.264 / AAC)…")
        progress(.converting(source.duration == nil ? nil : 0))
        let result: (Int32, Bool) = await withCheckedContinuation { continuation in
            runner.run(executable: ffmpeg, arguments: args, line: { text in
                if text.hasPrefix("out_time_us="), let duration = source.duration,
                   let micros = Double(text.dropFirst("out_time_us=".count)), micros.isFinite {
                    progress(.converting(min(0.99, max(0, micros / 1_000_000 / duration))))
                } else if text == "progress=end" {
                    progress(.finalizing)
                } else if !["frame=", "fps=", "stream_", "bitrate=", "total_size=", "out_time", "dup_frames=", "drop_frames=", "speed=", "progress="].contains(where: { text.hasPrefix($0) }) {
                    line(text)
                }
            },
                       completion: { continuation.resume(returning: ($0, $1)) })
        }
        if result.1 { throw CancellationError() }
        guard result.0 == 0 else { throw DownloadCommand.InputError.invalid("Převod pro Apple selhal (\(result.0)). Původní soubor zůstal zachován.") }
        progress(.finalizing)
        guard try await probe(temporary.path, executable: ffprobe, runner: runner).compatible else {
            throw DownloadCommand.InputError.invalid("Výsledné video neprošlo kontrolou H.264 / AAC. Původní soubor zůstal zachován.")
        }
        // Same-directory atomic replacement: a failed encode never overwrites the download.
        guard rename(temporary.path, original.path) == 0 else {
            throw DownloadCommand.InputError.invalid("Nelze uložit kompatibilní video. Původní soubor zůstal zachován.")
        }
    }
}
