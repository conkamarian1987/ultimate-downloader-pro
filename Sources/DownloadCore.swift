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
    var formatSelector: String? = nil
    var subtitleLanguage: String? = nil
    var imageOptions: ImageOptions? = nil
    var displayTitle: String? = nil
    var referer: String? = nil
    var trimStart: Double? = nil
    var trimEnd: Double? = nil
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
