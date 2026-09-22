import AppKit
import UniformTypeIdentifiers

final class ShareViewController: NSViewController {
    private let field = NSTextField(wrappingLabelWithString:"Načítám sdílený odkaz…")
    private let button = NSButton(title:"Otevřít v Ultimate Downloader",target:nil,action:nil)
    private var link: String?
    override func loadView() {
        view = NSView(frame:NSRect(x:0,y:0,width:440,height:180))
        field.frame = NSRect(x:24,y:75,width:392,height:75); view.addSubview(field)
        button.frame = NSRect(x:24,y:24,width:290,height:32); button.target = self; button.action = #selector(sendLink); button.isEnabled = false; view.addSubview(button)
        let cancel = NSButton(title:"Zrušit",target:self,action:#selector(cancelShare)); cancel.frame = NSRect(x:330,y:24,width:85,height:32); view.addSubview(cancel)
    }
    override func viewDidAppear() {
        super.viewDidAppear()
        for item in extensionContext?.inputItems as? [NSExtensionItem] ?? [] {
            for provider in item.attachments ?? [] {
                let type = provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) ? UTType.url.identifier : UTType.plainText.identifier
                guard provider.hasItemConformingToTypeIdentifier(type) else { continue }
                provider.loadItem(forTypeIdentifier:type,options:nil) { [weak self] result,error in
                    let text = (result as? URL)?.absoluteString ?? result as? String
                    DispatchQueue.main.async {
                        guard let self, self.link == nil else { return }
                        if let text, let detector = try? NSDataDetector(types:NSTextCheckingResult.CheckingType.link.rawValue),
                           let match = detector.firstMatch(in:text,range:NSRange(text.startIndex...,in:text)), let url = match.url,
                           ["http","https"].contains(url.scheme ?? "") {
                            self.link = url.absoluteString; self.field.stringValue = url.absoluteString; self.button.isEnabled = true
                        } else { self.field.stringValue = "Ve výběru není webový odkaz." }
                    }
                }
            }
        }
    }
    @objc private func sendLink() {
        guard let link else { return }
        var components = URLComponents(); components.scheme = "ultimatedownloader"; components.host = "download"; components.queryItems = [URLQueryItem(name:"url",value:link)]
        if let url = components.url, NSWorkspace.shared.open(url) { extensionContext?.completeRequest(returningItems:nil) }
        else { field.stringValue = "Aplikaci se nepodařilo otevřít. Přesuňte ji do Aplikací a jednou ji spusťte." }
    }
    @objc private func cancelShare() { extensionContext?.cancelRequest(withError:NSError(domain:NSCocoaErrorDomain,code:NSUserCancelledError)) }
}
