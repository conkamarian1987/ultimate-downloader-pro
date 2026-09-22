import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImageOptions: Codable, Hashable {
    var format = "original"
    var maxDimension = 0
}
enum ImageDownload {
    static func run(url: String, referer: String?, folder: String, title: String, options: ImageOptions) async throws -> String {
        guard let source = URL(string:url), ["https","http"].contains(source.scheme ?? "") else { throw URLError(.badURL) }
        var request = URLRequest(url:source,timeoutInterval:60)
        if let referer { request.setValue(referer,forHTTPHeaderField:"Referer") }
        let (temporary,response) = try await URLSession.shared.download(for:request)
        defer { try? FileManager.default.removeItem(at:temporary) }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        try Task.checkCancellation()
        guard let input = CGImageSourceCreateWithURL(temporary as CFURL,nil), let type = CGImageSourceGetType(input),
              let ut = UTType(type as String), ut.conforms(to:.image) else { throw DownloadCommand.InputError.invalid("Server nevrátil podporovaný obrázek.") }
        let ext = options.format == "original" && options.maxDimension == 0 ? (ut.preferredFilenameExtension ?? "img") : options.format == "jpeg" ? "jpg" : "png"
        let cleaned = title.components(separatedBy:CharacterSet.alphanumerics.union(.init(charactersIn:" -_" )).inverted).joined(separator:"_")
        let base = String(cleaned.prefix(100)).isEmpty ? "Obrázek" : String(cleaned.prefix(100))
        var destination = URL(fileURLWithPath:folder).appendingPathComponent(base).appendingPathExtension(ext)
        var count = 1
        while FileManager.default.fileExists(atPath:destination.path) { destination = URL(fileURLWithPath:folder).appendingPathComponent("\(base) (\(count))").appendingPathExtension(ext); count += 1 }
        if options.format == "original" && options.maxDimension == 0 { try FileManager.default.copyItem(at:temporary,to:destination) }
        else {
            let properties = CGImageSourceCopyPropertiesAtIndex(input,0,nil) as? [CFString:Any]
            let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 1
            let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 1
            let edge = options.maxDimension > 0 ? min(options.maxDimension,max(width,height)) : max(width,height)
            guard let image = CGImageSourceCreateThumbnailAtIndex(input,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:edge,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary),
                  let output = CGImageDestinationCreateWithURL(destination as CFURL,(options.format == "jpeg" ? UTType.jpeg.identifier : UTType.png.identifier) as CFString,1,nil) else { throw DownloadCommand.InputError.invalid("Obrázek nelze převést.") }
            CGImageDestinationAddImage(output,image,[kCGImageDestinationLossyCompressionQuality:0.92] as CFDictionary)
            guard CGImageDestinationFinalize(output) else { throw DownloadCommand.InputError.invalid("Obrázek nelze uložit.") }
        }
        return destination.path
    }
}
