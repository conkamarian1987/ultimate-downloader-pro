import Foundation

struct HellspyReference: Codable, Hashable {
    let id: Int
    let fileHash: String
    let quality: String
}
struct HellspyVideo: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let fileHash: String
    let size: Int64?
    let duration: Double?
    let thumbs: [String]?
}
struct HellspyDetail: Decodable {
    let conversions: [String: String]
    var qualities: [String] { conversions.keys.filter { Int($0) != nil }.sorted { (Int($0) ?? 0) > (Int($1) ?? 0) } }
    func stream(_ quality: String) throws -> URL {
        guard let value = conversions[quality], let url = URL(string: value), url.scheme == "https", url.host != nil else {
            throw DownloadCommand.InputError.invalid("Tato kvalita již není dostupná. Načtěte video znovu.")
        }
        return url
    }
}
struct HellspyPage: Decodable {
    let items: [HellspyVideo]
    let nextOffset: Int?
}
enum HellspyAPI {
    static let pageSize = 64
    private static func request<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DownloadCommand.InputError.invalid("Hellspy nyní neodpovídá nebo video není dostupné. Zkuste to znovu.")
        }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw DownloadCommand.InputError.invalid("Hellspy vrátil neočekávanou odpověď. Zkuste to později.") }
    }
    static func search(_ query: String, offset: Int) async throws -> HellspyPage {
        var url = URLComponents(string: "https://api.hellspy.to/gw/search")!
        url.queryItems = [.init(name: "query", value: query), .init(name: "offset", value: String(offset)), .init(name: "limit", value: String(pageSize))]
        return try await request(url.url!)
    }
    static func detail(id: Int, hash: String) async throws -> HellspyDetail {
        guard id > 0, !hash.isEmpty, hash.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else {
            throw DownloadCommand.InputError.invalid("Neplatný identifikátor videa.")
        }
        return try await request(URL(string: "https://api.hellspy.to/gw/video/\(id)/\(hash)")!)
    }
    static func download(_ reference: HellspyReference, folder: String, title: String, progress: @escaping @Sendable (TransferProgress) -> Void) async throws -> String {
        // Resolve at the head of the queue; CDN links expire and must not be saved in history.
        let detail = try await detail(id: reference.id, hash: reference.fileHash)
        let url = try detail.stream(reference.quality)
        let transfer = VideoDownloadTransfer(progress: progress)
        let (temporary, response) = try await transfer.download(url)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              !(http.mimeType ?? "").contains("text"), !(http.mimeType ?? "").contains("json") else {
            throw DownloadCommand.InputError.invalid("Server neposkytl video. Zkuste stažení znovu.")
        }
        let safe = String(title.map { "/\\:\n\r".contains($0) ? "_" : $0 }.prefix(150))
        let name = safe.isEmpty ? "Hellspy" : safe
        var target = URL(fileURLWithPath: folder).appendingPathComponent("\(name) - \(reference.quality)p.mp4")
        var number = 2
        while FileManager.default.fileExists(atPath: target.path) {
            target = URL(fileURLWithPath: folder).appendingPathComponent("\(name) - \(reference.quality)p (\(number)).mp4"); number += 1
        }
        try FileManager.default.moveItem(at: temporary, to: target)
        return target.path
    }
}
struct TransferProgress: Sendable {
    let received: Int64
    let expected: Int64?
    let bytesPerSecond: Double
    var fraction: Double? { expected.map { min(1, Double(received) / Double($0)) } }
    var detail: String {
        let amount = ByteCountFormatter.string(fromByteCount: received, countStyle: .file)
        let total = expected.map { " / " + ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? ""
        let rate = ByteCountFormatter.string(fromByteCount: Int64(max(0, bytesPerSecond)), countStyle: .file) + "/s"
        let percent = fraction.map { "\(Int($0 * 100)) % · " } ?? ""
        return percent + amount + total + " · " + rate
    }
}

/// A session-level delegate receives byte callbacks throughout the transfer.
/// The temporary file is moved before didFinishDownloadingTo returns.
final class VideoDownloadTransfer: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let progress: @Sendable (TransferProgress) -> Void
    private let lock = NSLock()
    private var continuation: CheckedContinuation<(URL, URLResponse), Error>?
    private var task: URLSessionDownloadTask?
    private var session: URLSession?
    private var cancelled = false
    private var result: Result<(URL, URLResponse), Error>?
    private var lastTime = ProcessInfo.processInfo.systemUptime
    private var lastBytes: Int64 = 0
    init(progress: @escaping @Sendable (TransferProgress) -> Void) { self.progress = progress }
    func download(_ url: URL) async throws -> (URL, URLResponse) {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if cancelled { lock.unlock(); continuation.resume(throwing: CancellationError()); return }
                self.continuation = continuation
                let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
                let config = URLSessionConfiguration.ephemeral
                config.timeoutIntervalForRequest = 60
                let session = URLSession(configuration: config, delegate: self, delegateQueue: queue)
                self.session = session
                let task = session.downloadTask(with: url); self.task = task
                lastTime = ProcessInfo.processInfo.systemUptime
                task.resume(); lock.unlock()
            }
        } onCancel: {
            self.lock.lock(); self.cancelled = true; let task = self.task; self.lock.unlock()
            task?.cancel()
        }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let now = ProcessInfo.processInfo.systemUptime
        let interval = now - lastTime
        guard interval >= 0.25 || totalBytesWritten == totalBytesExpectedToWrite else { return }
        let rate = Double(totalBytesWritten - lastBytes) / max(interval, 0.001)
        progress(TransferProgress(received: totalBytesWritten, expected: totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil, bytesPerSecond: rate))
        lastTime = now; lastBytes = totalBytesWritten
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            guard let response = downloadTask.response else { throw URLError(.badServerResponse) }
            let target = FileManager.default.temporaryDirectory.appendingPathComponent("udp-transfer-" + UUID().uuidString)
            try FileManager.default.moveItem(at: location, to: target)
            result = .success((target, response))
        } catch { result = .failure(error) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let continuation = self.continuation; self.continuation = nil
        let wasCancelled = cancelled
        self.task = nil; self.session = nil
        lock.unlock()
        let failure: Error? = wasCancelled ? CancellationError() : error
        if let failure {
            if case .success(let (url, _)) = result { try? FileManager.default.removeItem(at: url) }
            continuation?.resume(throwing: failure)
        } else { continuation?.resume(with: result ?? .failure(URLError(.cannotCreateFile))) }
        session.finishTasksAndInvalidate()
    }
}
