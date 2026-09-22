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
