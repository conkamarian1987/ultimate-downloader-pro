import Foundation
import WebKit

/// Cookies belong to this app's own WebKit session, never to Safari's storage.
@MainActor enum BrowserSession {
    static func cookies(for text: String) async -> [HTTPCookie] {
        guard let host = URL(string:text)?.host?.lowercased() else { return [] }
        let all = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        return all.filter { cookie in
            let domain = cookie.domain.lowercased().trimmingCharacters(in:CharacterSet(charactersIn:"."))
            return (host == domain || host.hasSuffix("." + domain)) && (cookie.expiresDate == nil || cookie.expiresDate! > Date())
        }
    }
    static func export(for text: String) async -> URL? {
        let cookies = await cookies(for:text)
        guard !cookies.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ultimate-session-\(UUID().uuidString).txt")
        var lines = ["# Netscape HTTP Cookie File"]
        for c in cookies {
            guard !c.name.contains("\t"), !c.value.contains("\n"), !c.value.contains("\t") else { continue }
            lines.append([c.domain,c.domain.hasPrefix(".") ? "TRUE" : "FALSE",c.path,c.isSecure ? "TRUE" : "FALSE",String(Int(c.expiresDate?.timeIntervalSince1970 ?? 0)),c.name,c.value].joined(separator:"\t"))
        }
        guard FileManager.default.createFile(atPath:url.path,contents:Data(lines.joined(separator:"\n").utf8),attributes:[.posixPermissions:0o600]) else { return nil }
        return url
    }
}
