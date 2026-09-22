import Foundation
import SwiftUI

struct MediaService: Identifiable, Hashable {
    let id: String, name: String, icon: String, detail: String
    let hue: Double
    let gallery: Bool
    var color: Color { Color(hue: hue, saturation: 0.75, brightness: 0.92) }
    static let all: [Self] = [
        .init(id:"youtube",name:"YouTube",icon:"play.rectangle.fill",detail:"Videa · hudba · playlisty",hue:0,gallery:false),
        .init(id:"instagram",name:"Instagram",icon:"camera",detail:"Reels · fotky · galerie",hue:0.87,gallery:true),
        .init(id:"tiktok",name:"TikTok",icon:"music.note",detail:"Videa · foto příspěvky",hue:0.49,gallery:true),
        .init(id:"facebook",name:"Facebook",icon:"f.square.fill",detail:"Veřejná videa",hue:0.60,gallery:false),
        .init(id:"twitter",name:"X / Twitter",icon:"x.square",detail:"Videa · obrázky",hue:0.58,gallery:true),
        .init(id:"pinterest",name:"Pinterest",icon:"pin.fill",detail:"Piny · obrázky · videa",hue:0.98,gallery:true),
        .init(id:"vimeo",name:"Vimeo",icon:"v.square.fill",detail:"Videa a filmy",hue:0.53,gallery:false),
        .init(id:"soundcloud",name:"SoundCloud",icon:"cloud.fill",detail:"Skladby · alba",hue:0.07,gallery:false),
        .init(id:"twitch",name:"Twitch",icon:"bubble.left.and.bubble.right.fill",detail:"Klipy · záznamy",hue:0.73,gallery:false),
        .init(id:"reddit",name:"Reddit",icon:"bubble.left.fill",detail:"Videa · galerie",hue:0.04,gallery:true),
        .init(id:"dailymotion",name:"Dailymotion",icon:"play.square.fill",detail:"Videa",hue:0.60,gallery:false),
        .init(id:"bandcamp",name:"Bandcamp",icon:"waveform",detail:"Veřejné skladby a alba",hue:0.51,gallery:false),
        .init(id:"flickr",name:"Flickr",icon:"camera.macro",detail:"Fotografie · alba",hue:0.90,gallery:true),
        .init(id:"tumblr",name:"Tumblr",icon:"t.square.fill",detail:"Fotky · videa",hue:0.61,gallery:true),
        .init(id:"bluesky",name:"Bluesky",icon:"cloud",detail:"Obrázky · videa",hue:0.57,gallery:true),
        .init(id:"mastodon",name:"Mastodon",icon:"bubble.left.and.text.bubble.right",detail:"Veřejné příspěvky",hue:0.70,gallery:true),
        .init(id:"imgur",name:"Imgur",icon:"photo.stack",detail:"Obrázky · GIF · alba",hue:0.37,gallery:true),
        .init(id:"deviantart",name:"DeviantArt",icon:"paintpalette",detail:"Ilustrace · galerie",hue:0.40,gallery:true),
        .init(id:"bilibili",name:"Bilibili",icon:"tv",detail:"Videa",hue:0.53,gallery:false),
        .init(id:"vk",name:"VK",icon:"v.circle.fill",detail:"Videa · veřejná média",hue:0.59,gallery:true),
        .init(id:"archive",name:"Internet Archive",icon:"building.columns",detail:"Veřejná mediální sbírka",hue:0.10,gallery:false),
        .init(id:"web",name:"Libovolný web",icon:"globe",detail:"Průzkum obrázků, audia a videa",hue:0.46,gallery:false)
    ]
}

enum MediaKind: String, Codable, CaseIterable { case video = "Video", audio = "Audio", image = "Obrázek" }
struct MediaVariant: Identifiable, Hashable {
    let id: String
    let label: String
    let ext: String
    let height: Int?
    let audioOnly: Bool
    let hasAudio: Bool
    let size: Int64?
}
struct MediaItem: Identifiable, Hashable {
    var id: String { url }
    let url: String
    let title: String
    let kind: MediaKind
    var thumbnail: String?
    var width: Int?
    var height: Int?
    var duration: Double?
    var variants: [MediaVariant] = []
    var subtitles: [String] = []
    var direct = false
    var referer: String?
    var dimensionLabel: String { if let w = width, let h = height { return "\(w) × \(h)" }; return "Rozměry zdroj neposkytl" }
}

/// Extractor JSON is data only; it is never executed or interpolated in a shell.
enum MediaParser {
    static func yt(_ object: [String: Any], fallback: String) -> [MediaItem] {
        if let entries = object["entries"] as? [[String: Any]] {
            return entries.flatMap { yt($0, fallback: fallback) }
        }
        let url = object["webpage_url"] as? String ?? object["original_url"] as? String ?? object["url"] as? String ?? fallback
        guard url.hasPrefix("http") else { return [] }
        let formats = object["formats"] as? [[String:Any]] ?? []
        let variants = formats.compactMap { f -> MediaVariant? in
            guard let id = f["format_id"] as? String, !id.isEmpty,
                  f["has_drm"] as? Bool != true, f["ext"] as? String != "mhtml" else { return nil }
            let audioOnly = (f["vcodec"] as? String) == "none"
            let hasAudio = (f["acodec"] as? String).map { $0 != "none" } ?? false
            let height = f["height"] as? Int
            let ext = f["ext"] as? String ?? ""
            let bitrate = (f["abr"] as? Double).map { " · \(Int($0)) kb/s" } ?? ""
            let size = (f["filesize"] as? NSNumber ?? f["filesize_approx"] as? NSNumber)?.int64Value
            let resolution = height.map { "\($0)p" } ?? (f["resolution"] as? String ?? "zdroj")
            let label = "\(audioOnly ? "Audio" : resolution) · \(ext.uppercased())\(audioOnly ? bitrate : hasAudio ? " · se zvukem" : " + zvuk")" + (size.map { " · " + ByteCountFormatter.string(fromByteCount:$0,countStyle:.file) } ?? "")
            return MediaVariant(id:id,label:label,ext:ext,height:height,audioOnly:audioOnly,hasAudio:hasAudio,size:size)
        }
        let thumbs = object["thumbnails"] as? [[String:Any]]
        let kind: MediaKind = (object["vcodec"] as? String == "none" || (!variants.isEmpty && variants.allSatisfy(\.audioOnly))) ? .audio : .video
        return [MediaItem(url:url,title:object["title"] as? String ?? url,kind:kind,
                         thumbnail:object["thumbnail"] as? String ?? thumbs?.last?["url"] as? String,
                         width:object["width"] as? Int,height:object["height"] as? Int,duration:object["duration"] as? Double,
                         variants:variants,subtitles:(object["subtitles"] as? [String:Any])?.keys.sorted() ?? [])]
    }
    static func gallery(_ data: Data, referer: String) -> [MediaItem] {
        guard let entries = try? JSONSerialization.jsonObject(with:data) as? [[Any]] else { return [] }
        return entries.compactMap { entry in
            guard entry.count >= 3, entry[0] as? Int == 3, let url = entry[1] as? String,
                  url.hasPrefix("http"), let meta = entry[2] as? [String:Any] else { return nil }
            let ext = meta["extension"] as? String ?? URL(string:url)?.pathExtension ?? ""
            let video = ["mp4","webm","mov","m3u8"].contains(ext.lowercased())
            return MediaItem(url:url,title:meta["filename"] as? String ?? URL(string:url)?.lastPathComponent ?? "Médium",
                             kind:video ? .video : .image,thumbnail:video ? nil : url,width:meta["width"] as? Int,height:meta["height"] as? Int,direct:true,referer:referer)
        }
    }
}

final class CapturedOutput: @unchecked Sendable {
    private let lock = NSLock(); private var value = ""
    func append(_ s: String) { lock.lock(); defer { lock.unlock() }; if value.utf8.count < 24_000_000 { value += s + "\n" } }
    func get() -> String { lock.lock(); defer { lock.unlock() }; return value }
}

@MainActor final class MediaExplorer: ObservableObject {
    @Published var items: [MediaItem] = []
    @Published var busy = false
    @Published var status = "Vložte odkaz a nechte aplikaci načíst dostupná média."
    @Published var diagnostics = ""
    @Published var selected = Set<String>()
    private var runners: [ProcessRunner] = []
    private var task: Task<Void,Never>?
    private var generation = UUID()
    let scanner = PageScanner()

    func cancel() { generation = UUID(); task?.cancel(); task = nil; runners.forEach { $0.cancel() }; runners = []; scanner.cancel(); busy = false; status = "Načítání zrušeno." }
    private func output(executable: String, args: [String]) async -> (String,Int32) {
        let runner = ProcessRunner(); runners.append(runner)
        let target = args.last?.hasPrefix("ytsearch") == true ? "https://www.youtube.com" : args.last ?? ""
        let cookieFile = await BrowserSession.export(for:target)
        defer { if let cookieFile { try? FileManager.default.removeItem(at:cookieFile) } }
        var arguments = args
        if let cookieFile { arguments.insert(contentsOf:["--cookies",cookieFile.path],at:0) }
        let capture = CapturedOutput()
        let watchdog = Task { try? await Task.sleep(for:.seconds(55)); if !Task.isCancelled { capture.append("Načítání překročilo časový limit 55 sekund."); runner.cancel() } }
        let result: (String,Int32) = await withCheckedContinuation { continuation in
            runner.run(executable:executable,arguments:arguments,line:{capture.append($0)},completion:{code,_ in continuation.resume(returning:(capture.get(),code))})
        }
        watchdog.cancel(); return result
    }
    func search(_ query: String) {
        guard !query.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return }
        cancel(); busy = true; items = []; selected = []; diagnostics = ""; status = "Hledám na YouTube…"
        let token = generation
        task = Task {
            guard let yt = ToolPaths.current.downloader else { status = "Chybí yt-dlp."; busy = false; return }
            let (out,code) = await output(executable:yt,args:["--ignore-config","--flat-playlist","--dump-single-json","--no-warnings","--socket-timeout","15","--retries","1","--","ytsearch16:" + query])
            guard token == generation else { return }
            items = parseYT(out,fallback:""); diagnostics = code == 0 ? "" : out
            status = items.isEmpty ? "Vyhledávání nevrátilo výsledky. Zkuste přímý odkaz nebo otevřete YouTube." : "Nalezeno \(items.count) videí. Vyberte video pro načtení kvalit."
            busy = false; runners = []
        }
    }
    func inspect(_ text: String, service: MediaService?, scanPage: Bool = false) {
        guard let url = try? DownloadCommand.validatedURLs(text).first else { status = "Vložte platný odkaz http nebo https."; return }
        cancel(); busy = true; items = []; selected = []; diagnostics = ""; status = "Zjišťuji dostupná média…"
        let token = generation
        task = Task {
            if scanPage {
                do { let found = try await scanner.scan(url); if token == generation { merge(found) } }
                catch { if token == generation { diagnostics += "Průzkum stránky: \(error.localizedDescription)\n" } }
            }
            guard token == generation else { return }
            if let yt = ToolPaths.current.downloader {
                status = "Zjišťuji video, audio a dostupné kvality…"
                let (out,code) = await output(executable:yt,args:["--ignore-config","--dump-single-json","--skip-download","--no-warnings","--socket-timeout","12","--retries","1","--extractor-retries","1","--playlist-end","50","--",url])
                guard token == generation else { return }
                merge(parseYT(out,fallback:url)); if code != 0 { diagnostics += "Video/audio: " + String(out.suffix(2500)) + "\n" }
            }
            if service?.gallery == true || scanPage {
                if let gallery = ToolPaths.find("gallery-dl") {
                    status = "Procházím obrázkovou galerii…"
                    let (out,code) = await output(executable:gallery,args:["--config-ignore","--dump-json","--range","1-100","--retries","1","--http-timeout","12","--",url])
                    guard token == generation else { return }
                    // Logs can precede JSON; start at the first standalone opening bracket.
                    let cleaned = out.range(of:"[\n").map { String(out[$0.lowerBound...]) } ?? out
                    merge(MediaParser.gallery(Data(cleaned.utf8),referer:url))
                    if let messages = try? JSONSerialization.jsonObject(with:Data(cleaned.utf8)) as? [[Any]] {
                        for message in messages where message.first as? Int == -1 {
                            if let data = message.last as? [String:Any] { diagnostics += "Galerie: " + (data["message"] as? String ?? "Zdroj odmítl načtení.") + "\n" }
                        }
                    }
                    if code != 0 { diagnostics += "Galerie: " + String(out.suffix(1500)) }
                } else { diagnostics += "Pro galerie nainstalujte gallery-dl v Nástrojích.\n" }
            }
            guard token == generation else { return }
            if !scanPage && items.isEmpty {
                do { let found = try await scanner.scan(url); if token == generation { merge(found) } }
                catch { if token == generation { diagnostics += "\n\(error.localizedDescription)" } }
            }
            guard token == generation else { return }
            status = items.isEmpty ? "Média nebyla nalezena. Stránka může vyžadovat přihlášení nebo nemusí být podporovaná." : "Nalezeno \(items.count) položek. Vyberte, co chcete uložit."
            busy = false; runners = []
        }
    }
    private func parseYT(_ out: String, fallback: String) -> [MediaItem] {
        out.split(separator:"\n").flatMap { line -> [MediaItem] in
            guard line.first == "{", let o = try? JSONSerialization.jsonObject(with:Data(line.utf8)) as? [String:Any] else { return [] }
            return MediaParser.yt(o,fallback:fallback)
        }
    }
    private func merge(_ list: [MediaItem]) { for item in list { if !items.contains(where: { $0.url == item.url }) { items.append(item) } } }
}
