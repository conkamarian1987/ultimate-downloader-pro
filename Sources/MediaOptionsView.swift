import SwiftUI

struct MediaOptionsView: View {
    let items: [MediaItem]
    let folder: String
    var playlistURL: String? = nil
    @EnvironmentObject var store: DownloadStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var details = MediaExplorer()
    @State private var output = "video"
    @State private var profileID = "1080"
    @State private var container = "mp4"
    @State private var variantID = "auto"
    @State private var subtitle = "none"
    @State private var imageFormat = "original"
    @State private var dimension = 0
    @State private var enqueued = false
    @AppStorage("savedMediaPresets") private var presetData = Data()
    @State private var presetName = ""
    @State private var trimEnabled = false
    @State private var trimStart = "0"
    @State private var trimEnd = ""
    var presets: [SavedMediaPreset] { (try? JSONDecoder().decode([SavedMediaPreset].self, from: presetData)) ?? [] }
    var validTrim: Bool { !trimEnabled || (Self.seconds(trimStart) != nil && (trimEnd.isEmpty || (Self.seconds(trimEnd) ?? -1) > (Self.seconds(trimStart) ?? 0))) }
    static func seconds(_ text: String) -> Double? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }
        var total = 0.0
        for (i, part) in parts.enumerated() {
            guard let value = Double(part.replacingOccurrences(of: ",", with: ".")), value.isFinite, value >= 0, (i == 0 || value < 60) else { return nil }
            total = total * 60 + value
        }
        return total
    }
    var current: MediaItem? { details.items.first ?? items.first }
    var hasImages: Bool { items.contains { $0.kind == .image } }
    var hasAV: Bool { items.contains { $0.kind != .image } }
    var profiles: [DownloadProfile] { output == "audio" ? DownloadProfile.audio : DownloadProfile.video }
    var variants: [MediaVariant] { current?.variants.filter { output == "audio" ? $0.audioOnly : !$0.audioOnly } ?? [] }
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            HStack { VStack(alignment:.leading,spacing:6) { Text(items.count == 1 ? "Přesně podle vás." : "Uložit \(items.count) položek").font(.title.bold()); Text(current?.title ?? "Výběr médií").foregroundStyle(.secondary).lineLimit(2) }; Spacer(); Button("Zavřít") { details.cancel(); dismiss() } }
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    GroupBox("Oblíbené profily") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(presets) { preset in
                                HStack {
                                    Button(preset.name) { output = preset.output; profileID = preset.profileID; container = preset.container; imageFormat = preset.imageFormat; dimension = preset.dimension; variantID = "auto" }
                                    Spacer()
                                    Button(role: .destructive) { presetData = (try? JSONEncoder().encode(presets.filter { $0.id != preset.id })) ?? Data() } label: { Image(systemName: "trash") }.help("Smazat profil")
                                }
                            }
                            HStack {
                                TextField("Název nového profilu", text: $presetName)
                                Button("Uložit aktuální volby") {
                                    var saved = presets
                                    saved.append(SavedMediaPreset(name: presetName.trimmingCharacters(in: .whitespaces), output: output, profileID: profileID, container: container, imageFormat: imageFormat, dimension: dimension))
                                    presetData = (try? JSONEncoder().encode(saved)) ?? Data(); presetName = ""
                                }.disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            Text("Uloží formát a kvalitu videa, zvuku a obrázků. Časový výřez se nastavuje pro konkrétní stažení.").font(.caption).foregroundStyle(.secondary)
                        }.padding(12)
                    }
                    if details.busy { HStack { ProgressView().controlSize(.small); Text("Načítám dostupné formáty a kvality…") } }
                    if !details.diagnostics.isEmpty { DisclosureGroup("Informace o zdroji") { Text(details.diagnostics).font(.caption).textSelection(.enabled) } }
                    if hasAV {
                        GroupBox("Video a hudba") {
                            VStack(alignment:.leading,spacing:16) {
                                Picker("Uložit jako",selection:$output) { Text("Video").tag("video"); Text("Pouze zvuk").tag("audio") }.pickerStyle(.segmented).onChange(of:output) { _,v in if !profiles.contains(where: { $0.id == profileID }) { profileID = v == "audio" ? "mp3-320" : "1080" }; variantID = "auto" }
                                if output == "video" {
                                    Picker("Kontejner",selection:$container) { Text("MP4").tag("mp4"); Text("MKV").tag("mkv"); Text("WebM").tag("webm") }
                                    if items.count == 1 && !variants.isEmpty {
                                        Picker("Dostupná stopa",selection:$variantID) { Text("Automaticky podle profilu").tag("auto"); ForEach(variants.reversed()) { Text($0.label).tag($0.id) } }
                                    }
                                }
                                if variantID == "auto" || output == "audio" { Picker("Kvalita / formát",selection:$profileID) { ForEach(profiles) { Text($0.title).tag($0.id) } } }
                                if !trimEnabled, items.count == 1, let languages = current?.subtitles, !languages.isEmpty {
                                    Picker("Titulky jako SRT",selection:$subtitle) { Text("Bez titulků").tag("none"); ForEach(languages,id:\.self) { Text($0).tag($0) } }
                                }
                                Text(output == "audio" ? "Převod nemůže zvýšit kvalitu zdrojového zvuku. Datový tok je cílová hodnota." : "Kvalita je horní limit. Stopy se nepřepočítávají na vyšší rozlišení. Kontejner musí podporovat kodeky zdroje; MKV bývá nejuniverzálnější.").font(.caption).foregroundStyle(.secondary)
                                if variants.isEmpty && !details.busy { Text("Zdroj neposkytl seznam variant. Použije se zvolený profil; u přímých souborů bez údajů o rozlišení zvolte nejvyšší dostupnou kvalitu.").font(.caption).foregroundStyle(.orange) }
                            }.padding(12)
                        }
                    }
                    if hasAV {
                        GroupBox("Časový výřez") {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle("Uložit jen část videa nebo zvuku", isOn: $trimEnabled)
                                if trimEnabled {
                                    HStack { TextField("Od (0:30)", text: $trimStart); TextField("Do (prázdné = konec)", text: $trimEnd) }
                                    Text("Čas v sekundách nebo hh:mm:ss. Přesný střih může vyžadovat nové kódování. Titulky se u výřezu nestahují. U playlistu se výřez použije na každou položku.").font(.caption).foregroundStyle(.secondary)
                                    if !validTrim { Text("Zadejte platný začátek a konec pozdější než začátek.").foregroundStyle(.orange) }
                                }
                            }.padding(12)
                        }
                    }
                    if hasImages {
                        GroupBox("Obrázky") {
                            VStack(alignment:.leading,spacing:16) {
                                if let item = current, items.count == 1 { Text("Zdroj: " + item.dimensionLabel).foregroundStyle(.secondary) }
                                Picker("Formát",selection:$imageFormat) { Text("Originál").tag("original"); Text("JPEG").tag("jpeg"); Text("PNG").tag("png") }
                                Picker("Delší strana",selection:$dimension) { Text("Původní rozlišení").tag(0); Text("Max. 3840 px").tag(3840); Text("Max. 2560 px").tag(2560); Text("Max. 1920 px").tag(1920); Text("Max. 1280 px").tag(1280) }
                                Text("Obrázky se pouze zmenšují. Originál zachová původní soubor včetně animace; převod nebo změna velikosti uloží první snímek. Zmenšený originál se uloží jako PNG.").font(.caption).foregroundStyle(.secondary)
                            }.padding(12)
                        }
                    }
                    Label(folder,systemImage:"folder").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            HStack { Text("Soubory se zařadí do společné fronty.").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Přidat do fronty") { enqueue() }.buttonStyle(NeonButtonStyle()).controlSize(.large).disabled(details.busy || enqueued || !validTrim) }
        }.padding(28).frame(width:700,height:610)
        .task {
            if items.count == 1, playlistURL == nil, let first = items.first {
                if first.kind == .audio { output = "audio"; profileID = "mp3-320" }
                if first.kind != .image && !first.direct && first.variants.isEmpty { details.inspect(first.url,service:nil) }
                if first.direct && first.kind == .video { profileID = "max" }
            }
        }
        .onDisappear { details.cancel() }
    }
    func enqueue() {
        guard validTrim else { return }
        let start = trimEnabled && hasAV ? Self.seconds(trimStart) : nil
        let end = trimEnabled && hasAV && !trimEnd.isEmpty ? Self.seconds(trimEnd) : nil
        guard let base = profiles.first(where:{$0.id == profileID}) else { return }
        let selectedVariant = variants.first(where:{$0.id == variantID})
        let profile = output == "video" ? DownloadProfile(id:base.id,title:"\(container.uppercased()) · \(selectedVariant?.label ?? base.title)",format:container,quality:base.quality,suffix:selectedVariant?.id ?? base.suffix) : base
        let selector: String? = output == "video" ? selectedVariant.map { $0.hasAudio ? $0.id : "\($0.id)+bestaudio/\($0.id)" } : nil
        if let playlistURL { store.enqueue(text:playlistURL,profile:profile,playlist:true,folder:folder,trimStart:start,trimEnd:end); enqueued = true; dismiss(); return }
        store.enqueueMedia(items,profile:profile,selector:selector,subtitles:trimEnabled || subtitle == "none" ? nil : subtitle,imageOptions:ImageOptions(format:imageFormat,maxDimension:dimension),folder:folder,trimStart:start,trimEnd:end)
        enqueued = true; dismiss()
    }
}
