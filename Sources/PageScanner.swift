import WebKit
import SwiftUI

@MainActor final class PageScanner: NSObject, WKNavigationDelegate {
    private var web: WKWebView?
    private var continuation: CheckedContinuation<[MediaItem],Error>?
    private var timeout: Task<Void,Never>?
    func cancel() { finish(.failure(CancellationError())) }
    func scan(_ url: String) async throws -> [MediaItem] {
        cancel()
        return try await withCheckedThrowingContinuation { c in
            continuation = c
            let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent()
            config.mediaTypesRequiringUserActionForPlayback = .all
            let view = WKWebView(frame:CGRect(x:0,y:0,width:1200,height:900),configuration:config)
            view.navigationDelegate = self; web = view
            view.load(URLRequest(url:URL(string:url)!,timeoutInterval:25))
            timeout = Task { try? await Task.sleep(for:.seconds(30)); if !Task.isCancelled { finish(.failure(URLError(.timedOut))) } }
        }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { [weak self, weak webView] in
            try? await Task.sleep(for:.seconds(1.5))
            guard let self, let view = webView, self.web === view else { return }
            do {
                let result = try await view.evaluateJavaScript(Self.script)
                let values = result as? [[String:Any]] ?? []
                let items = values.compactMap { v -> MediaItem? in
                    guard let url = v["url"] as? String, url.hasPrefix("http"), let type = v["kind"] as? String else { return nil }
                    return MediaItem(url:url,title:v["title"] as? String ?? "Médium",kind:type == "image" ? .image : type == "audio" ? .audio : .video,
                                     thumbnail:type == "image" ? url : v["poster"] as? String,width:v["width"] as? Int,height:v["height"] as? Int,direct:true,referer:view.url?.absoluteString)
                }
                finish(.success(items))
            } catch { finish(.failure(error)) }
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    private func finish(_ result: Result<[MediaItem],Error>) {
        timeout?.cancel(); timeout = nil; web?.stopLoading(); web?.navigationDelegate = nil; web = nil
        let c = continuation; continuation = nil; c?.resume(with:result)
    }
    static let script = #"""
    (() => {
      const found = new Map();
      const add = (raw, kind, title, width, height, poster) => {
        if (!raw) return;
        try { const url = new URL(raw, document.baseURI).href;
          if (!/^https?:/.test(url) || found.has(url) || found.size >= 500) return;
          found.set(url,{url,kind,title:title || decodeURIComponent(new URL(url).pathname.split('/').pop()) || document.title,width:width||null,height:height||null,poster:poster||null});
        } catch (_) {}
      };
      document.querySelectorAll('img').forEach(e => {
        add(e.currentSrc || e.src,'image',e.alt,e.naturalWidth,e.naturalHeight);
        for (const key of ['data-src','data-original','data-lazy-src']) add(e.getAttribute(key),'image',e.alt);
        (e.srcset || '').split(',').forEach(s => add(s.trim().split(/\s+/)[0],'image',e.alt));
      });
      document.querySelectorAll('picture source').forEach(e => (e.srcset||'').split(',').forEach(s => add(s.trim().split(/\s+/)[0],'image')));
      document.querySelectorAll('video,audio').forEach(e => {
        const kind = e.tagName.toLowerCase(); add(e.currentSrc || e.src,kind,document.title,e.videoWidth,e.videoHeight,e.poster);
        e.querySelectorAll('source').forEach(s=>add(s.src,kind,document.title,e.videoWidth,e.videoHeight,e.poster));
        if (e.poster) add(e.poster,'image',document.title+' – náhled');
      });
      document.querySelectorAll('meta[property^="og:image"],meta[name="twitter:image"]').forEach(e=>add(e.content,'image',document.title));
      document.querySelectorAll('meta[property="og:video"],meta[property="og:video:url"]').forEach(e=>add(e.content,'video',document.title));
      document.querySelectorAll('a[href]').forEach(e=>{
        const path = new URL(e.href,document.baseURI).pathname.toLowerCase();
        const kind = /\.(png|jpg|jpeg|webp|gif|avif|heic)$/.test(path)?'image':/\.(mp4|webm|mov|m3u8|mpd)$/.test(path)?'video':/\.(mp3|m4a|wav|flac|ogg|opus)$/.test(path)?'audio':null;
        if(kind)add(e.href,kind,e.textContent.trim());
      });
      document.querySelectorAll('[style]').forEach(e=>{const b=getComputedStyle(e).backgroundImage;for(const m of b.matchAll(/url\(["']?(.*?)["']?\)/g))add(m[1],'image');});
      return Array.from(found.values());
    })()
    """#
}

struct WebPlayer: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration(); configuration.mediaTypesRequiringUserActionForPlayback = .all
        let view = WKWebView(frame:.zero,configuration:configuration); view.allowsBackForwardNavigationGestures = true
        view.load(URLRequest(url:url)); return view
    }
    func updateNSView(_ view: WKWebView, context: Context) { if view.url == nil { view.load(URLRequest(url:url)) } }
    static func dismantleNSView(_ view: WKWebView, coordinator: ()) { view.stopLoading(); view.loadHTMLString("",baseURL:nil) }
}


/// A video-only YouTube player; login/source browsing continues to use WebPlayer.
struct YouTubePlayer: View {
    let url: URL
    var body: some View {
        if let id = Self.videoID(url) {
            EmbeddedYouTubePlayer(videoID: id)
        } else {
            ContentUnavailableView("Tento odkaz není odkaz na video", systemImage: "play.slash",
                                   description: Text("Vyberte konkrétní video z výsledků vyhledávání."))
        }
    }

    static func videoID(_ url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""
        let parts = url.path.split(separator: "/").map(String.init)
        let candidate: String?
        if host == "youtu.be" || host == "www.youtu.be" {
            candidate = parts.first
        } else if ["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com", "www.youtube-nocookie.com", "youtube-nocookie.com"].contains(host) {
            if parts.first == "watch" {
                candidate = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "v" })?.value
            } else if parts.count == 2 && ["shorts", "embed", "live"].contains(parts[0]) {
                candidate = parts[1]
            } else { candidate = nil }
        } else { candidate = nil }
        guard let candidate, candidate.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil else { return nil }
        return candidate
    }
}

private struct EmbeddedYouTubePlayer: NSViewRepresentable {
    let videoID: String
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {
        guard context.coordinator.loadedID != videoID else { return }
        context.coordinator.loadedID = videoID
        let destination = URL(string: "https://www.youtube.com/embed/\(videoID)?playsinline=1&controls=1&rel=0")!
        var request = URLRequest(url: destination)
        // YouTube requires app identification for native WebView embeds (error 153 otherwise).
        let appID = Bundle.main.bundleIdentifier ?? "cz.ultimate.downloaderpro"
        request.setValue("https://" + appID.lowercased(), forHTTPHeaderField: "Referer")
        view.load(request)
    }
    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading()
        view.navigationDelegate = nil
        view.uiDelegate = nil
        view.loadHTMLString("", baseURL: nil)
    }
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var loadedID: String?
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Deliberate player links may open separately, never replace the video with a website.
            if action.navigationType == .linkActivated, let url = action.request.url,
               action.targetFrame?.isMainFrame != false {
                if ["https", "http"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if action.navigationType == .linkActivated, let url = action.request.url,
               ["https", "http"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) }
            return nil
        }
    }
}
