import SwiftUI
import AppKit

private let neon = Color(red:0.15,green:0.78,blue:0.71)
struct MediaSelection: Identifiable { let id = UUID(); let items: [MediaItem]; var playlistURL: String? = nil }
struct PlayerSelection: Identifiable { var id: String { url.absoluteString }; let url: URL }

struct StudioView: View {
    @EnvironmentObject var store: DownloadStore
    @AppStorage("clipboardMonitoring") private var clipboardEnabled = false
    @StateObject private var clipboard = ClipboardMonitor()
    @StateObject private var explorer = MediaExplorer()
    @Environment(\.colorScheme) private var scheme
    @AppStorage("theme") private var theme = "system"
    @AppStorage("destination") private var folder = FileManager.default.urls(for:.downloadsDirectory,in:.userDomainMask)[0].path
    @State private var route = "home"
    @State private var service = MediaService.all[0]
    @State private var input = ""
    @State private var serviceFilter = ""
    @State private var mediaFilter = "Vše"
    @State private var selection: MediaSelection?
    @State private var player: PlayerSelection?
    @State private var logJob: DownloadJob?
    @State private var showDiagnostics = false
    @State private var showClearHistoryConfirmation = false
    private var background: Color { scheme == .dark ? Color(red:0.035,green:0.05,blue:0.085) : Color(red:0.94,green:0.96,blue:0.98) }
    private var surface: Color { scheme == .dark ? Color.white.opacity(0.045) : .white }
    private var accent: Color { scheme == .dark ? neon : Color(red:0.0,green:0.38,blue:0.34) }
    private var secondaryText: Color { scheme == .dark ? Color.white.opacity(0.70) : Color(red:0.24,green:0.27,blue:0.30) }
    private var tertiaryText: Color { scheme == .dark ? Color.white.opacity(0.50) : Color(red:0.34,green:0.37,blue:0.40) }
    private var filtered: [MediaItem] { explorer.items.filter { mediaFilter == "Vše" || $0.kind.rawValue == mediaFilter } }
    var body: some View {
        HStack(spacing:0) {
            sidebar.frame(width:224)
            Divider()
            ScrollView {
                VStack(alignment:.leading,spacing:24) {
                    if let link = clipboard.candidate {
                        HStack { Image(systemName: "doc.on.clipboard"); Text(link).lineLimit(1); Button("Použít odkaz") { input = link; route = "scan"; clipboard.candidate = nil }; Button("Zavřít") { clipboard.candidate = nil } }.padding().background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }
                    if route == "home" { home }
                    else if route == "queue" { queue }
                    else if route == "settings" { settings }
                    else { discover }
                }.padding(32).frame(maxWidth:1300,alignment:.leading).frame(maxWidth:.infinity)
            }.background(background)
        }
        .background(background).tint(accent).frame(minWidth:1000,minHeight:720)
        .preferredColorScheme(theme == "dark" ? .dark : theme == "light" ? .light : nil)
        .sheet(item:$selection) { selected in MediaOptionsView(items:selected.items,folder:folder,playlistURL:selected.playlistURL).environmentObject(store) }
        .sheet(item:$player) { selected in
            VStack(spacing:0) {
                HStack { Label("Přehrávač / zdrojová stránka",systemImage:"play.rectangle").font(.headline); Spacer(); Link("Otevřít v Safari",destination:selected.url); Button("Zavřít") { player = nil } }.padding()
                WebPlayer(url:selected.url).id(selected.id)
                Text("Přehrávání ovládá zdrojová služba. Přihlášení nebo souhlas se mohou zobrazit přímo v přehrávači.").font(.caption).foregroundStyle(secondaryText).padding(10)
            }.frame(width:1000,height:700)
        }
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
    private var sidebar: some View {
        VStack(alignment:.leading,spacing:26) {
            HStack(spacing:12) { Image(systemName:"arrow.down.square.fill").font(.system(size:32)).foregroundStyle(accent); VStack(alignment:.leading,spacing:3) { Text("ULTIMATE").font(.system(size:17,weight:.heavy,design:.rounded)); Text("DOWNLOADER PRO").font(.system(size:9,weight:.semibold,design:.monospaced)).tracking(1).foregroundStyle(secondaryText) } }.padding(.top,20)
            VStack(spacing:8) {
                nav("home","Domů","square.grid.2x2.fill")
                nav("scan","Průzkum stránky","sparkle.magnifyingglass")
                nav("queue","Fronta a historie","arrow.down.circle",badge:store.waitingCount)
                nav("settings","Nastavení","slider.horizontal.3")
            }
            Text("RYCHLÝ PŘÍSTUP").font(.system(size:10,weight:.semibold,design:.monospaced)).tracking(2).foregroundStyle(secondaryText)
            ForEach(Array(MediaService.all.prefix(6))) { item in
                Button { choose(item) } label: { HStack(spacing:12) { Image(systemName:item.icon).foregroundStyle(item.color).frame(width:22); Text(item.name); Spacer() }.padding(.vertical,3) }.buttonStyle(.plain)
            }
            Spacer()
            VStack(alignment:.leading,spacing:9) {
                HStack { Circle().fill(store.tools.ready ? accent : .orange).frame(width:6,height:6); Text(store.tools.ready ? "Stahovací nástroje připravené" : "Zkontrolujte nástroje").font(.caption2) }
                Text("BETA 0.3.1  /  macOS").font(.system(size:10,design:.monospaced)).foregroundStyle(tertiaryText)
            }
        }.padding(22).background(scheme == .dark ? Color(red:0.055,green:0.07,blue:0.11) : Color.white)
    }
    private func nav(_ id: String,_ text: String,_ icon: String,badge: Int = 0) -> some View {
        Button { route = id } label: {
            HStack { Image(systemName:icon).frame(width:22); Text(text).font(.system(size:13,weight:.medium)); Spacer(); if badge > 0 { Text("\(badge)").font(.caption.bold()).padding(4).background(accent.opacity(0.2),in:Capsule()) } }
                .padding(12).foregroundStyle(route == id ? accent : .primary).background(route == id ? accent.opacity(0.12) : .clear,in:RoundedRectangle(cornerRadius:10))
        }.buttonStyle(.plain)
    }
    private var home: some View {
        VStack(alignment:.leading,spacing:28) {
            HStack { Text("VAŠE MÉDIA. BEZ CHAOSU.").font(.system(size:11,weight:.medium,design:.monospaced)).tracking(2).foregroundStyle(accent); Spacer(); Text(Date(),style:.date).font(.caption).foregroundStyle(secondaryText) }
            HStack {
                VStack(alignment:.leading,spacing:16) {
                    Text("Vítejte.\nCo dnes stáhneme?").font(.system(size:42,weight:.bold,design:.rounded))
                    Text("Video, hudba a obrázky. Vyberte službu, prozkoumejte odkaz\na uložte přesně to, co chcete.").foregroundStyle(secondaryText).lineSpacing(5)
                    Button { route = "scan" } label: { Label("Prozkoumat odkaz",systemImage:"sparkles").padding(.vertical,7).padding(.horizontal,10) }.buttonStyle(NeonButtonStyle())
                }
                Spacer()
                ZStack {
                    Circle().stroke(accent.opacity(0.15),lineWidth:1).frame(width:200,height:200)
                    Circle().stroke(accent.opacity(0.3),lineWidth:1).frame(width:150,height:150)
                    Image(systemName:"arrow.down.to.line.compact").font(.system(size:70,weight:.ultraLight)).foregroundStyle(accent)
                    Image(systemName:"photo").font(.title2).padding(14).background(surface,in:RoundedRectangle(cornerRadius:15)).offset(x:75,y:-65)
                    Image(systemName:"waveform").font(.title2).padding(14).background(surface,in:RoundedRectangle(cornerRadius:15)).offset(x:-78,y:56)
                }.frame(width:230,height:230).accessibilityHidden(true)
            }.padding(28).frame(maxWidth:.infinity).background(LinearGradient(colors:[accent.opacity(0.08),Color.blue.opacity(0.05),surface],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:24))
            HStack { Text("Odkud dnes stahujeme?").font(.title2.bold()); Spacer(); TextField("Najít službu…",text:$serviceFilter).textFieldStyle(.roundedBorder).frame(width:210) }
            LazyVGrid(columns:[GridItem(.adaptive(minimum:170),spacing:14)],spacing:14) {
                ForEach(MediaService.all.filter { serviceFilter.isEmpty || $0.name.localizedCaseInsensitiveContains(serviceFilter) }) { item in
                    Button { choose(item) } label: {
                        VStack(alignment:.leading,spacing:12) {
                            HStack { Image(systemName:item.icon).font(.system(size:26)).foregroundStyle(item.color).frame(width:48,height:48).background(item.color.opacity(0.12),in:RoundedRectangle(cornerRadius:13)); Spacer(); Image(systemName:"arrow.up.right").font(.caption).foregroundStyle(tertiaryText) }
                            Text(item.name).font(.headline).foregroundStyle(.primary)
                            Text(item.detail).font(.caption).foregroundStyle(secondaryText).lineLimit(1)
                        }.padding(17).frame(maxWidth:.infinity,alignment:.leading).background(surface,in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(.primary.opacity(0.06)))
                    }.buttonStyle(.plain)
                }
            }
            Text("A další weby přes univerzální odkaz. Dostupnost konkrétních médií ověří analýza; některé služby vyžadují přihlášení nebo omezují stahování.").font(.caption).foregroundStyle(secondaryText)
        }
    }
    private func choose(_ item: MediaService) { explorer.cancel(); explorer.items = []; explorer.status = "Vložte odkaz nebo vyhledávací dotaz."; input = ""; service = item; route = item.id == "web" ? "scan" : "service" }
    private var discover: some View {
        VStack(alignment:.leading,spacing:20) {
            HStack {
                Image(systemName:route == "scan" ? "sparkle.magnifyingglass" : service.icon).font(.system(size:34)).foregroundStyle(route == "scan" ? accent : service.color)
                VStack(alignment:.leading,spacing:5) { Text(route == "scan" ? "Průzkum stránky" : service.name).font(.largeTitle.bold()); Text(route == "scan" ? "Obrázky, audio a video nalezené na jedné stránce." : service.detail).foregroundStyle(secondaryText) }
                Spacer()
            }
            HStack(spacing:12) {
                TextField(service.id == "youtube" && route != "scan" ? "Hledat na YouTube nebo vložit URL…" : "Vložte odkaz na příspěvek, galerii nebo stránku…",text:$input).textFieldStyle(.plain).padding(15).background(surface,in:RoundedRectangle(cornerRadius:12)).onSubmit { analyze() }
                Button { input = NSPasteboard.general.string(forType:.string) ?? "" } label: { Image(systemName:"doc.on.clipboard").padding(8) }.help("Vložit ze schránky")
                Button(explorer.busy ? "Zrušit" : "Prozkoumat") { if explorer.busy { explorer.cancel() } else { analyze() } }.buttonStyle(NeonButtonStyle()).controlSize(.large)
            }
            HStack { if explorer.busy { ProgressView().controlSize(.small) }; Text(explorer.status).font(.callout).foregroundStyle(secondaryText); Spacer(); if !explorer.diagnostics.isEmpty { Button("Podrobnosti") { showDiagnostics.toggle() } } }
            if showDiagnostics && !explorer.diagnostics.isEmpty { Text(explorer.diagnostics).font(.system(.caption,design:.monospaced)).textSelection(.enabled).padding().background(surface,in:RoundedRectangle(cornerRadius:12)) }
            if route == "service" && input.hasPrefix("http") && !service.gallery {
                Button("Stáhnout celý playlist / album z odkazu") { selection = MediaSelection(items:[MediaItem(url:input,title:"Celý playlist / album",kind:.video)],playlistURL:input) }
            }
            if route == "scan" { Text("Průzkum zahrnuje načtená média, odkazy na soubory a podporované galerie. Nevidí chráněné streamy ani obsah, který stránka ještě nenačetla. Limit: 500 prvků stránky, 100 položek galerie, 50 videí.").font(.caption).foregroundStyle(secondaryText) }
            if !explorer.items.isEmpty {
                HStack {
                    Picker("Typ",selection:$mediaFilter) { Text("Vše").tag("Vše"); ForEach(MediaKind.allCases,id:\.self) { Text($0.rawValue).tag($0.rawValue) } }.pickerStyle(.segmented).frame(width:340)
                    Spacer(); Button("Vybrat zobrazené") { explorer.selected.formUnion(filtered.map(\.id)) }
                    if !explorer.selected.isEmpty { Button("Zrušit výběr") { explorer.selected = [] }; Button("Stáhnout výběr (\(explorer.selected.count))") { selection = MediaSelection(items:explorer.items.filter { explorer.selected.contains($0.id) }) }.buttonStyle(.borderedProminent) }
                }
                LazyVGrid(columns:[GridItem(.adaptive(minimum:235),spacing:16)],spacing:16) { ForEach(filtered) { mediaCard($0) } }
            } else if !explorer.busy {
                VStack(spacing:15) { Image(systemName:route == "scan" ? "globe" : service.icon).font(.system(size:65,weight:.ultraLight)).foregroundStyle(accent.opacity(0.75)); Text(service.id == "youtube" && route != "scan" ? "Vyhledejte video, nebo vložte odkaz." : "Každé stažení začíná odkazem.").font(.title3); Text("Nejprve zobrazíme náhledy a dostupné možnosti.").foregroundStyle(secondaryText) }.frame(maxWidth:.infinity).padding(.vertical,60)
            }
        }
    }
    private func analyze() {
        showDiagnostics = false; mediaFilter = "Vše"
        if service.id == "youtube" && route != "scan" && !input.trimmingCharacters(in:.whitespacesAndNewlines).hasPrefix("http") { explorer.search(input) }
        else { explorer.inspect(input,service:route == "scan" ? nil : service,scanPage:route == "scan") }
    }
    private func mediaCard(_ item: MediaItem) -> some View {
        VStack(alignment:.leading,spacing:12) {
            ZStack(alignment:.topTrailing) {
                thumbnail(item).frame(height:145).clipped().clipShape(RoundedRectangle(cornerRadius:10))
                Toggle("Vybrat",isOn:Binding(get:{explorer.selected.contains(item.id)},set:{if $0 {explorer.selected.insert(item.id)} else {explorer.selected.remove(item.id)}})).labelsHidden().toggleStyle(.checkbox).padding(9).background(.regularMaterial,in:RoundedRectangle(cornerRadius:8)).padding(7)
            }
            Text(item.title).font(.headline).lineLimit(2).frame(height:38,alignment:.topLeading)
            Text(item.kind == .image ? item.dimensionLabel : item.kind.rawValue + (item.duration.map { " · \(Int($0)/60):" + String(format:"%02d",Int($0)%60) } ?? "")).font(.caption).foregroundStyle(secondaryText)
            HStack {
                if item.kind != .image { Button { if let url = URL(string:item.url) { player = PlayerSelection(url:url) } } label: { Image(systemName:"play.fill") }.help("Přehrát ve zdrojové stránce") }
                Button(item.kind == .image ? "Rozměry a uložení" : "Kvalita a stažení") { selection = MediaSelection(items:[item]) }.frame(maxWidth:.infinity)
            }
        }.padding(12).background(surface,in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(explorer.selected.contains(item.id) ? accent : .primary.opacity(0.06),lineWidth:1))
    }
    @ViewBuilder private func thumbnail(_ item: MediaItem) -> some View {
        if let text = item.thumbnail, let url = URL(string:text) {
            AsyncImage(url:url) { image in image.resizable().scaledToFit().frame(maxWidth:.infinity,maxHeight:.infinity) } placeholder: { placeholder(item) }
        } else { placeholder(item) }
    }
    private func placeholder(_ item: MediaItem) -> some View { ZStack { LinearGradient(colors:[accent.opacity(0.09),.blue.opacity(0.08)],startPoint:.topLeading,endPoint:.bottomTrailing); Image(systemName:item.kind == .image ? "photo" : item.kind == .audio ? "waveform" : "play.rectangle").font(.largeTitle).foregroundStyle(accent) }.frame(maxWidth:.infinity,maxHeight:.infinity) }
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
            if store.jobs.isEmpty { ContentUnavailableView("Připraveno na první odkaz",systemImage:"tray",description:Text("Vyberte službu na domovské obrazovce.")) }
            ForEach(store.jobs) { job in
                VStack(alignment:.leading,spacing:12) {
                    HStack { Image(systemName:job.imageOptions != nil ? "photo" : job.profile.isAudio ? "waveform" : "film").font(.title2).foregroundStyle(accent); VStack(alignment:.leading,spacing:5) { Text(job.displayTitle ?? job.profile.title).font(.headline).lineLimit(1); Text(job.url).font(.caption).foregroundStyle(secondaryText).lineLimit(1) }; Spacer(); Text(job.state.rawValue).font(.caption.bold()).foregroundStyle(job.state == .failed ? .red : accent) }
                    if job.state == .running { ProgressView(value:job.progress) }
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
            Text("Karty služeb jsou rychlé vstupy do podporovaných extraktorů. Funkčnost konkrétního odkazu závisí na poskytovateli. Aplikace neobchází DRM ani přístupová oprávnění.").font(.caption).foregroundStyle(secondaryText)
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
