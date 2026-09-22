import Foundation
import AppKit
import ImageIO

@main struct StudioTests {
    @MainActor static func main() async throws {
        let root = URL(fileURLWithPath:CommandLine.arguments[1])
        let source = try Data(contentsOf:root.appendingPathComponent("ProviderTests/youtube-search.json"))
        let object = try JSONSerialization.jsonObject(with:source) as! [String:Any]
        let search = MediaParser.yt(object,fallback:"")
        precondition(search.count == 3 && search.allSatisfy { $0.url.hasPrefix("https://www.youtube.com/") })
        let variants:[String:Any] = ["title":"Test","webpage_url":"https://example.com/1","formats":[["format_id":"v","ext":"mp4","height":1080,"vcodec":"h264","acodec":"none"],["format_id":"a","ext":"m4a","vcodec":"none","acodec":"aac","abr":128],["format_id":"drm","ext":"mp4","has_drm":true]]]
        let item = MediaParser.yt(variants,fallback:"")[0]; precondition(item.variants.count == 2 && item.variants[1].audioOnly)
        let gallery = Data("[[3,\"https://example.com/a.jpg\",{\"extension\":\"jpg\",\"width\":600,\"height\":400,\"filename\":\"image\"}]]".utf8)
        let g = MediaParser.gallery(gallery,referer:"https://example.com")
        precondition(g.count == 1 && g[0].width == 600 && g[0].kind == .image)
        let folder = root.appendingPathComponent("studio-test-output"); try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        for options in [ImageOptions(),ImageOptions(format:"jpeg",maxDimension:128),ImageOptions(format:"png",maxDimension:256)] {
            let path = try await ImageDownload.run(url:"http://127.0.0.1:18766/picture.png",referer:nil,folder:folder.path,title:"test",options:options)
            let img = CGImageSourceCreateWithURL(URL(fileURLWithPath:path) as CFURL,nil)!
            let info = CGImageSourceCopyPropertiesAtIndex(img,0,nil) as! [CFString:Any]
            let width = info[kCGImagePropertyPixelWidth] as! Int
            precondition(width == (options.maxDimension == 0 ? 512 : options.maxDimension))
            print("PASS image \(options.format) \(width)px")
        }
        let scanner = PageScanner()
        let media = try await scanner.scan("http://127.0.0.1:18766/media-page.html")
        precondition(media.contains { $0.kind == .image && $0.width == 512 })
        precondition(media.contains { $0.kind == .video })
        print("PASS DOM scan: \(media.count) items")
        var job = DownloadJob(url:"https://example.com/video",profile:.init(id:"mkv",title:"MKV",format:"mkv",quality:1080,suffix:"1080"),playlist:false,folder:folder.path)
        job.formatSelector="137+bestaudio/137";job.subtitleLanguage="cs"
        let args=DownloadCommand.arguments(for:job,ffmpeg:"/opt/homebrew/bin/ffmpeg")
        precondition(args.contains("mkv") && args.contains("137+bestaudio/137") && args.contains("cs") && !job.profile.isAudio)
        print("PASS search parser, variants, DRM filtering, galleries, MKV, exact selection, subtitles")
    }
}
