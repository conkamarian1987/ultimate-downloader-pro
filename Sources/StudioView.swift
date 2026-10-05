import SwiftUI
import AppKit

private let neon = Color(red:0.15,green:0.78,blue:0.71)
struct MediaSelection: Identifiable { let id = UUID(); let items: [MediaItem]; var playlistURL: String? = nil }
struct PlayerSelection: Identifiable { var id: String { url.absoluteString }; let url: URL }

struct StudioView: View {
    @EnvironmentObject private var updates: AppUpdates
    @EnvironmentObject var store: DownloadStore
    @AppStorage("clipboardMonitoring") private var clipboardEnabled = false
    @StateObject private var clipboard = ClipboardMonitor()
    @Environment(\.colorScheme) private var scheme
    @AppStorage("theme") private var theme = "system"
    @AppStorage("destination") private var folder = FileManager.default.urls(for:.downloadsDirectory,in:.userDomainMask)[0].path
    @State private var route = "scan"
    @State private var showSettings = false
    @State private var input = ""
    @State private var player: PlayerSelection?
    @State private var logJob: DownloadJob?
    @State private var showClearHistoryConfirmation = false
    private var background: Color { scheme == .dark ? Color(red:0.035,green:0.05,blue:0.085) : Color(red:0.94,green:0.96,blue:0.98) }
    private var surface: Color { scheme == .dark ? Color.white.opacity(0.045) : .white }
    private var accent: Color { scheme == .dark ? neon : Color(red:0.0,green:0.38,blue:0.34) }
    private var secondaryText: Color { scheme == .dark ? Color.white.opacity(0.70) : Color(red:0.24,green:0.27,blue:0.30) }
    private var tertiaryText: Color { scheme == .dark ? Color.white.opacity(0.50) : Color(red:0.34,green:0.37,blue:0.40) }
    var body: some View {
        VStack(spacing:0) {
            HStack(spacing:16) {
                Label("Ultimate Downloader Pro", systemImage:"arrow.down.square.fill").font(.headline)
                Spacer()
                nav("scan", "Z odkazu", "link")
                nav("youtube", "YouTube", "play.rectangle")
                nav("hellspy", "Hellspy", "film")
                nav("queue", "Fronta", "arrow.down.circle", badge:store.waitingCount)
                Spacer()
                Button { showSettings = true } label: { Image(systemName:"gearshape").font(.title3) }.help("Nastavení")
            }.padding(18)
            Divider()
            ZStack {
                MediaWorkspace(youtube:false, incoming:$input, folder:folder, active:route == "scan")
                    .opacity(route == "scan" ? 1 : 0).allowsHitTesting(route == "scan").accessibilityHidden(route != "scan")
                MediaWorkspace(youtube:true, incoming:.constant(""), folder:folder, active:route == "youtube")
                    .opacity(route == "youtube" ? 1 : 0).allowsHitTesting(route == "youtube").accessibilityHidden(route != "youtube")
                HellspyView(folder: folder, active: route == "hellspy")
                    .opacity(route == "hellspy" ? 1 : 0).allowsHitTesting(route == "hellspy").accessibilityHidden(route != "hellspy")
                if route == "queue" { ScrollView { queue.padding(28) }.background(background) }
            }
            if let link = clipboard.candidate {
                HStack { Image(systemName:"doc.on.clipboard"); Text(link).lineLimit(1); Spacer(); Button("Použít odkaz") { input = link; route = "scan"; clipboard.candidate = nil }; Button("Zavřít") { clipboard.candidate = nil } }.padding(12)
            }
        }
        .sheet(isPresented:$showSettings) {
            VStack { HStack { Text("Nastavení").font(.title2.bold()); Spacer(); Button("Hotovo") { showSettings = false } }.padding(); ScrollView { settings.padding(24) } }.frame(width:800,height:680)
        .sheet(item:$player) { selected in
            VStack(spacing:0) {
                HStack { Label("Přehrávač / zdrojová stránka",systemImage:"play.rectangle").font(.headline); Spacer(); Link("Otevřít v Safari",destination:selected.url); Button("Zavřít") { player = nil } }.padding()
                WebPlayer(url:selected.url).id(selected.id)
                Text("Přehrávání ovládá zdrojová služba. Přihlášení nebo souhlas se mohou zobrazit přímo v přehrávači.").font(.caption).foregroundStyle(secondaryText).padding(10)
            }.frame(width:1000,height:700)
        }

        }
        .background(background).tint(accent).frame(minWidth:1000,minHeight:720)
        .preferredColorScheme(theme == "dark" ? .dark : theme == "light" ? .light : nil)
        .sheet(item:$logJob) { job in
            VStack(alignment:.leading,spacing:16) {
                HStack { Text("Protokol úlohy").font(.title2.bold()); Spacer(); Button("Zavřít") { logJob = nil } }
                ScrollView { Text(store.jobs.first(where:{$0.id == job.id})?.log ?? job.log).font(.system(.caption,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }
            }.padding(24).frame(width:780,height:500)
        }
        .alert("Ultimate Downloader",isPresented:Binding(get:{store.message != nil},set:{if !$0 {store.message = nil}})) { Button("Rozumím") { store.message = nil } } message: { Text(store.message ?? "") }
        .confirmationDialog("Vymazat historii fronty?", isPresented:$showClearHistoryConfirmation, titleVisibility:.visible) {
            Button("Vymazat pouze záznamy", role:.destructive) { store.clearHistory() }
            Button("Zrušit", role:.cancel) {}
        } message: {
            Text("Stažené soubory a složky zůstanou beze změny. Odstraní se jen dokončené, neúspěšné a zrušené záznamy.")
        }
        .onAppear { clipboard.setEnabled(clipboardEnabled) }
        .onChange(of: clipboardEnabled) { _, enabled in clipboard.setEnabled(enabled) }
        .onReceive(NotificationCenter.default.publisher(for: .init("ShowDownloadQueue"))) { _ in route = "queue" }
        .onOpenURL { url in
            let value = url.scheme == "ultimatedownloader" ? URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems?.first(where:{$0.name == "url"})?.value : url.absoluteString
            if let value { input = value; route = "scan" }
        }
        .onReceive(NotificationCenter.default.publisher(for:.init("IncomingMediaURL"))) { note in if let text = note.object as? String { input = text; route = "scan" } }
    }
    private func nav(_ id: String,_ text: String,_ icon: String,badge: Int = 0) -> some View {
        Button { route = id } label: {
            HStack { Image(systemName:icon).frame(width:22); Text(text).font(.system(size:13,weight:.medium)); if badge > 0 { Text("\(badge)").font(.caption.bold()).padding(4).background(accent.opacity(0.2),in:Capsule()) } }
                .padding(12).contentShape(Rectangle()).foregroundStyle(route == id ? accent : .primary).background(route == id ? accent.opacity(0.12) : .clear,in:RoundedRectangle(cornerRadius:10))
        }.buttonStyle(.plain)
    }
    private var queue: some View {
        VStack(alignment:.leading,spacing:20) {
            HStack {
                VStack(alignment:.leading,spacing:6) {
                    Text("Fronta a historie").font(.largeTitle.bold())
                    Text("\(store.completedCount) dokončených · \(store.waitingCount) čekajících nebo spuštěných").foregroundStyle(secondaryText)
                }
                Spacer()
                Button("Vymazat historii", systemImage:"trash", role:.destructive) { showClearHistoryConfirmation = true }
                    .disabled(store.historyCount == 0)
                    .help("Odstraní pouze záznamy. Stažené soubory zůstanou zachované.")
                Button(store.paused ? "Pokračovat" : "Pozastavit frontu") { store.togglePause() }
            }
            if store.paused { Text("Další úlohy čekají. Probíhající úlohu lze zrušit samostatně.").foregroundStyle(.orange) }
            if store.jobs.isEmpty { ContentUnavailableView("Připraveno na první odkaz",systemImage:"tray",description:Text("Vložte odkaz nebo vyhledejte video v záložce YouTube.")) }
            ForEach(store.jobs) { job in
                VStack(alignment:.leading,spacing:12) {
                    HStack { Image(systemName:job.imageOptions != nil ? "photo" : job.profile.isAudio ? "waveform" : "film").font(.title2).foregroundStyle(accent); VStack(alignment:.leading,spacing:5) { Text(job.displayTitle ?? job.profile.title).font(.headline).lineLimit(1); Text(job.url).font(.caption).foregroundStyle(secondaryText).lineLimit(1) }; Spacer(); Text(job.state == .running ? (job.conversionStage ?? job.state.rawValue) : job.state.rawValue).font(.caption.bold()).foregroundStyle(job.state == .failed ? .red : accent) }
                    if job.state == .running {
                        if job.conversionStage != nil {
                            if let progress = job.conversionProgress { ProgressView(value:progress) }
                            else { ProgressView().controlSize(.small) }
                        } else if job.hellspy != nil && job.downloadTotalBytes == nil { ProgressView() }
                        else { ProgressView(value:job.progress) }
                    }
                    Text(job.detail).font(.caption).foregroundStyle(secondaryText)
                    HStack { Text(job.created,style:.date).font(.caption2).foregroundStyle(tertiaryText); Spacer(); Button("Protokol") { logJob = job }; if job.state == .running || job.state == .queued { Button("Zrušit") { store.cancel(job.id) } } else { Button("Znovu") { store.retry(job) }; Button("Odebrat", systemImage:"trash", role:.destructive) { store.removeFromHistory(job.id) }.help("Odebere pouze záznam z historie. Stažený soubor zůstane zachovaný.") }; Button("Finder") { let urls = job.files.filter { FileManager.default.fileExists(atPath:$0) }.map { URL(fileURLWithPath:$0) }; if urls.isEmpty { NSWorkspace.shared.open(URL(fileURLWithPath:job.folder)) } else { NSWorkspace.shared.activateFileViewerSelecting(urls) } } }
                }.padding(20).background(surface,in:RoundedRectangle(cornerRadius:16))
            }
        }
    }
    private var settings: some View {
        VStack(alignment:.leading,spacing:24) {
            Text("Váš prostor. Vaše pravidla.").font(.largeTitle.bold())
            GroupBox("Vzhled") { Picker("Motiv",selection:$theme) { Text("Podle systému").tag("system"); Text("Dark Future").tag("dark"); Text("Světlý").tag("light") }.pickerStyle(.segmented).padding(12) }
            GroupBox("Ukládání") { HStack { Text(folder).lineLimit(2).textSelection(.enabled); Spacer(); Button("Vybrat složku…") { let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false; p.allowsMultipleSelection = false; if p.runModal() == .OK, let url = p.url { folder = url.path } } }.padding(12) }
            AppPreferencesView()
            GroupBox("Stahovací nástroje") {
                VStack(alignment:.leading,spacing:14) {
                    ForEach(["yt-dlp","ffmpeg","ffprobe","gallery-dl"],id:\.self) { name in HStack { Image(systemName:ToolPaths.find(name) == nil ? "exclamationmark.circle" : "checkmark.circle.fill").foregroundStyle(ToolPaths.find(name) == nil ? .orange : accent); Text(name).bold(); Spacer(); Text(ToolPaths.find(name) ?? "Nenalezeno").font(.caption).foregroundStyle(secondaryText) } }
                    HStack { Button("Obnovit stav") { store.tools = .current }; Button("Nainstalovat nástroje") { store.maintain(install:true) }.disabled(store.busy); Button("Aktualizovat") { store.maintain(install:false) }.disabled(store.busy); if store.maintenance { ProgressView().controlSize(.small); Button("Zrušit") {store.stopMaintenance()} } }
                    if !store.maintenanceLog.isEmpty { Text(store.maintenanceLog).font(.system(.caption,design:.monospaced)).textSelection(.enabled) }
                }.padding(12)
            }
            GroupBox("Aktualizace aplikace") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Aktuální verze se povinně ověřuje při každém spuštění aplikace. Během používání další kontroly neprobíhají.").font(.caption).foregroundStyle(secondaryText)
                    if !updates.status.isEmpty { Text(updates.status).font(.callout) }
                }.padding(12)
            }
            GroupBox("Přihlášení ke službám") {
                VStack(alignment:.leading,spacing:12) {
                    Text("Přihlaste se přímo na webu služby. Při načítání i stahování se použije pouze relace uložená v této aplikaci. Safari má vlastní oddělené přihlášení.").font(.caption).foregroundStyle(secondaryText)
                    HStack {
                        Button("Instagram") { player = PlayerSelection(url:URL(string:"https://www.instagram.com/accounts/login/")!) }
                        Button("TikTok") { player = PlayerSelection(url:URL(string:"https://www.tiktok.com/login")!) }
                        Button("YouTube") { player = PlayerSelection(url:URL(string:"https://www.youtube.com")!) }
                        Button("Facebook") { player = PlayerSelection(url:URL(string:"https://www.facebook.com")!) }
                    }
                }.padding(12)
            }
            Text("Funkčnost konkrétního odkazu závisí na poskytovateli. Aplikace neobchází DRM ani přístupová oprávnění.").font(.caption).foregroundStyle(secondaryText)
            HStack { Link("Podporované video služby",destination:URL(string:"https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md")!); Link("Podporované galerie",destination:URL(string:"https://gdl-org.github.io/docs/supportedsites.html")!) }
            GroupBox("O vývojáři") { DeveloperInfoView() }
        }
    }
}

struct NeonButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration:Configuration) -> some View {
        let fill = scheme == .dark ? neon : Color(red:0.0,green:0.38,blue:0.34)
        configuration.label.fontWeight(.semibold).padding(.horizontal,15).padding(.vertical,10)
            .foregroundStyle(enabled ? (scheme == .dark ? Color.black : Color.white) : Color.secondary)
            .background(enabled ? fill.opacity(configuration.isPressed ? 0.7 : 1) : Color.gray.opacity(0.15),in:RoundedRectangle(cornerRadius:10))
    }
}

struct MediaWorkspace: View {
    let youtube: Bool
    @Binding var incoming: String
    let folder: String
    let active: Bool
    @StateObject private var explorer = MediaExplorer()
    @State private var query = ""
    @State private var chosen: MediaItem?
    @State private var playback: URL?
    @State private var wholePlaylist = false
    @State private var analyzedURL = ""
    @State private var scanPage = false
    private var selectedItems: [MediaItem] {
        if let chosen { return [chosen] }
        return explorer.items.filter { explorer.selected.contains($0.id) }
    }
    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                Text(youtube ? "YouTube" : "Stáhnout z odkazu").font(.largeTitle.bold())
                HStack {
                    TextField(youtube ? "Hledat na YouTube nebo vložit odkaz…" : "Vložte odkaz na video, hudbu nebo galerii…",text:$query)
                        .textFieldStyle(.roundedBorder).controlSize(.large).onSubmit { analyze() }
                    Button { query = NSPasteboard.general.string(forType:.string) ?? "" } label: { Image(systemName:"doc.on.clipboard") }.help("Vložit ze schránky")
                    Button(explorer.busy ? "Zrušit" : youtube ? "Vyhledat" : "Načíst odkaz") { if explorer.busy { explorer.cancel() } else { analyze() } }.buttonStyle(NeonButtonStyle())
                }
                if !youtube { Toggle("Prohledat také obrázky a média na webové stránce",isOn:$scanPage).font(.caption) }
                HStack { if explorer.busy { ProgressView().controlSize(.small) }; Text(explorer.status).font(.callout).foregroundStyle(.secondary) }
                if !explorer.diagnostics.isEmpty { DisclosureGroup("Podrobnosti načítání") { Text(explorer.diagnostics).font(.caption.monospaced()).textSelection(.enabled) } }
                if youtube, let playback, active {
                    VStack(alignment:.leading) {
                        HStack { Text(chosen?.title ?? "Přehrávač").font(.headline); Spacer(); Button("Zavřít přehrávač") { self.playback = nil } }
                        YouTubePlayer(url:playback).id(playback).frame(height:390)
                            .id("player")
                    }
                }
                if !youtube || chosen != nil || !explorer.selected.isEmpty {
                    if !analyzedURL.isEmpty {
                        Toggle("Stáhnout celý playlist / album z odkazu",isOn:$wholePlaylist)
                    }
                    MediaOptionsView(items:wholePlaylist ? [MediaItem(url:analyzedURL,title:"Celý playlist / album",kind:.video)] : selectedItems,
                                     folder:folder,playlistURL:wholePlaylist ? analyzedURL : nil,embedded:true,loading:explorer.busy)
                        .background(.background,in:RoundedRectangle(cornerRadius:16)).id("options")
                }
                if !explorer.items.isEmpty {
                    HStack {
                        Text(youtube ? "Výsledky vyhledávání" : "Nalezená média").font(.title2.bold())
                        Spacer()
                        Button("Vybrat vše") { chosen = nil; explorer.selected = Set(explorer.items.map(\.id)); wholePlaylist = false }
                        if !explorer.selected.isEmpty { Button("Zrušit výběr") { explorer.selected = []; chosen = nil } }
                    }
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:240),spacing:16)],spacing:16) {
                        ForEach(explorer.items) { item in
                            VStack(alignment:.leading,spacing:12) {
                                ZStack(alignment:.topTrailing) {
                                    AsyncImage(url:URL(string:item.thumbnail ?? "")) { image in image.resizable().scaledToFit() } placeholder: { Image(systemName:item.kind == .image ? "photo" : "play.rectangle").font(.largeTitle).frame(maxWidth:.infinity,maxHeight:.infinity).background(.quaternary) }.frame(height:140).frame(maxWidth:.infinity).clipped()
                                    Toggle("Vybrat",isOn:Binding(get:{explorer.selected.contains(item.id)},set:{ value in chosen = nil; wholePlaylist = false; if value { explorer.selected.insert(item.id) } else { explorer.selected.remove(item.id) } })).labelsHidden().toggleStyle(.checkbox).padding(8).background(.regularMaterial)
                                }
                                Text(item.title).font(.headline).lineLimit(2).frame(height:40,alignment:.topLeading)
                                HStack {
                                    if youtube { Button("Přehrát") { choose(item); playback = URL(string:item.url) } }
                                    Button("Volby stažení") { choose(item) }
                                }
                            }.padding(14).background(.background,in:RoundedRectangle(cornerRadius:14))
                                .overlay(RoundedRectangle(cornerRadius:14).stroke(chosen?.id == item.id || explorer.selected.contains(item.id) ? Color.accentColor : .clear,lineWidth:2))
                        }
                    }
                } else if youtube && !explorer.busy {
                    ContentUnavailableView("Najděte video nebo hudbu",systemImage:"magnifyingglass",description:Text("Zadejte název, interpreta nebo odkaz. U výsledku můžete rovnou přehrávat i stahovat."))
                }
            }.padding(28).frame(maxWidth:1200).frame(maxWidth:.infinity)
        }
        .onChange(of:playback) { _, url in if url != nil { withAnimation { proxy.scrollTo("player",anchor:.top) } } }
        .onChange(of:chosen) { _, item in if item != nil { withAnimation { proxy.scrollTo(playback == nil ? "options" : "player",anchor:.top) } } }
        }
        .onChange(of:incoming) { _, value in if !value.isEmpty { query = value; incoming = "" } }
        .onChange(of:query) { _, _ in explorer.cancel(); explorer.status = "Načtěte odkaz nebo spusťte vyhledávání."; explorer.items = []; explorer.selected = []; chosen = nil; playback = nil; wholePlaylist = false; analyzedURL = "" }
        .onChange(of:explorer.busy) { _, busy in
            if !busy && !youtube && explorer.items.count == 1 { chosen = explorer.items.first }
        }
    }
    private func choose(_ item:MediaItem) { chosen = item; explorer.selected = []; wholePlaylist = false }
    private func analyze() {
        chosen = nil; playback = nil; wholePlaylist = false
        let value = query.trimmingCharacters(in:.whitespacesAndNewlines)
        if youtube && !value.lowercased().hasPrefix("http") { analyzedURL = ""; explorer.search(value) }
        else {
            guard let url = try? DownloadCommand.validatedURLs(value).first else { explorer.status = "Vložte platný odkaz http nebo https."; return }
            analyzedURL = url
            // Gallery extraction is attempted for generic links as well as video extraction.
            let service = youtube ? MediaService.all[0] : MediaService.all.first { $0.gallery }
            explorer.inspect(url,service:service,scanPage:!youtube && scanPage)
        }
    }
}
