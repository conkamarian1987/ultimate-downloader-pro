import SwiftUI

@MainActor final class HellspyBrowser: ObservableObject {
    @Published var query = ""
    @Published var videos: [HellspyVideo] = []
    @Published var busy = false
    @Published var error = ""
    @Published var more = false
    private let fetch: (String, Int) async throws -> HellspyPage
    init(fetch: @escaping (String, Int) async throws -> HellspyPage = { try await HellspyAPI.search($0, offset: $1) }) { self.fetch = fetch }
    private var searched = ""
    private var offset = 0
    private var searchTask: Task<Void, Never>?
    private var searchID = UUID()
    func search(next: Bool = false) {
        if next && (busy || !more) { return }
        let text = next ? searched : query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        searchTask?.cancel(); searchID = UUID(); let token = searchID
        if !next { videos = []; offset = 0; searched = text; more = false }
        busy = true; error = ""
        searchTask = Task {
            do {
                let results = try await fetch(text, offset)
                guard token == searchID, !Task.isCancelled else { return }
                let previousOffset = offset
                offset = results.nextOffset ?? 0
                for video in results.items where !videos.contains(where: { $0.id == video.id }) { videos.append(video) }
                more = results.nextOffset != nil && offset != previousOffset && !results.items.isEmpty
                if videos.isEmpty { error = "Nic nenalezeno. Zkuste jiný název." }
            } catch { if token == searchID, !Task.isCancelled { self.error = error.localizedDescription } }
            if token == searchID { busy = false }
        }
    }
    func cancel() { searchID = UUID(); searchTask?.cancel(); busy = false }
}

struct HellspyView: View {
    @EnvironmentObject var store: DownloadStore
    @StateObject private var browser = HellspyBrowser()
    @StateObject private var player = NativeVideoPlayer()
    let folder: String
    let active: Bool
    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Hellspy").font(.largeTitle.bold()).id("top")
                    HStack {
                        TextField("Název filmu nebo videa", text: $browser.query).textFieldStyle(.roundedBorder).onSubmit { browser.search() }
                        Button("Vyhledat", systemImage: "magnifyingglass") { browser.search() }.disabled(browser.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if browser.busy { ProgressView().controlSize(.small); Button("Zrušit") { browser.cancel() } }
                    }
                    if !browser.error.isEmpty { Text(browser.error).foregroundStyle(.secondary) }
                    if !player.title.isEmpty {
                        NativePlayerView(player: player).padding(14).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14)).id("player")
                    }
                    if !browser.videos.isEmpty { Text("Načteno \(browser.videos.count) videí").font(.caption).foregroundStyle(.secondary) }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 16)], spacing: 16) {
                        ForEach(browser.videos) { video in
                            HellspyVideoCard(video: video, player: player, folder: folder, active: active) {
                                withAnimation { scroll.scrollTo("player", anchor: .top) }
                            }
                        }
                    }
                    if browser.more {
                        HStack { Spacer(); Button(browser.busy ? "Načítám…" : "Další výsledky") { browser.search(next: true) }.disabled(browser.busy); Spacer() }
                            .onAppear { if active { browser.search(next: true) } }
                    }
                }.padding(26)
            }
        }
        .onChange(of: player.title) { _, title in store.mediaPlaybackActive = !title.isEmpty }
        .onChange(of: active) { _, value in if !value { browser.cancel(); player.stop() } }
        .onDisappear { browser.cancel(); player.stop() }
    }
}

private struct HellspyVideoCard: View {
    let video: HellspyVideo
    @ObservedObject var player: NativeVideoPlayer
    let folder: String
    let active: Bool
    let didPlay: () -> Void
    @EnvironmentObject var store: DownloadStore
    @State private var qualities: [String] = []
    @State private var quality = "auto"
    @State private var busy = false
    @State private var message = ""
    @State private var task: Task<Void, Never>?
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            AsyncImage(url: video.thumbs?.first.flatMap(URL.init(string:))) { image in image.resizable().scaledToFill() } placeholder: { Rectangle().fill(.gray.opacity(0.15)).overlay { Image(systemName: "film").font(.largeTitle) } }
                .frame(height: 140).clipped().clipShape(RoundedRectangle(cornerRadius: 8))
            Text(video.title).font(.headline).lineLimit(2).frame(height: 40, alignment: .topLeading)
            HStack { if let duration = video.duration { Text("\(Int(duration) / 60) min") }; Spacer(); if let size = video.size { Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) } }.font(.caption).foregroundStyle(.secondary)
            Picker("Kvalita", selection: $quality) {
                Text("Nejvyšší dostupná").tag("auto")
                ForEach(qualities, id: \.self) { Text("\($0)p").tag($0) }
            }.disabled(busy)
            if qualities.isEmpty { Button("Načíst další kvality") { perform(nil) }.font(.caption).disabled(busy) }
            HStack {
                Button("Přehrát", systemImage: "play.fill") { perform(true) }
                Spacer()
                Button("Stáhnout", systemImage: "arrow.down") { perform(false) }
            }.disabled(busy)
            if busy { ProgressView().controlSize(.small) }
            if !message.isEmpty { Text(message).font(.caption).foregroundStyle(.secondary) }
        }.padding(12).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        .onChange(of: active) { _, value in if !value { task?.cancel(); busy = false } }
        .onDisappear { task?.cancel(); busy = false }
    }
    private func perform(_ play: Bool?) {
        guard !busy else { return }
        busy = true; message = ""
        task = Task { @MainActor in
            defer { busy = false }
            do {
                let detail = try await HellspyAPI.detail(id: video.id, hash: video.fileHash)
                try Task.checkCancellation()
                qualities = detail.qualities
                guard let chosen = quality == "auto" ? qualities.first : quality else {
                    message = "Video nemá dostupnou kvalitu."; return
                }
                guard let play else { return }
                if play {
                    player.play(try detail.stream(chosen), title: "\(video.title) · \(chosen)p")
                    // Wait for SwiftUI to insert the player anchor before scrolling to it.
                    Task { @MainActor in await Task.yield(); didPlay() }
                } else {
                    store.enqueueHellspy(video, quality: chosen, folder: folder)
                    message = "Přidáno do fronty · \(chosen)p"
                }
            } catch { if !Task.isCancelled { message = error.localizedDescription } }
        }
    }
}
