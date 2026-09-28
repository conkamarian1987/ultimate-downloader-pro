import SwiftUI
import AppKit
import UserNotifications

@MainActor final class DownloadStore: ObservableObject {
    @Published var jobs: [DownloadJob] = []
    @Published var tools = ToolPaths.current
    @Published var maintenance = false
    @Published var maintenanceLog = ""
    @Published var message: String?
    @Published var paused = false
    private var imageTask: Task<Void,Never>?
    private var runner: ProcessRunner?
    private var activeID: UUID?
    private let historyURL: URL
    var busy: Bool { activeID != nil || maintenance }
    var completedCount: Int { jobs.filter { $0.state == .finished }.count }
    var waitingCount: Int { jobs.filter { $0.state == .queued || $0.state == .running }.count }
    var historyCount: Int { jobs.filter { $0.state != .queued && $0.state != .running }.count }

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("UltimateDownloaderPro")
        historyURL = folder.appendingPathComponent("history.json")
        if let data = try? Data(contentsOf: historyURL), let saved = try? JSONDecoder().decode([DownloadJob].self, from: data) {
            jobs = saved.map { job in
                var copy = job
                if copy.state == .running || copy.state == .queued {
                    copy.state = .cancelled; copy.detail = "Přerušeno ukončením aplikace. Můžete spustit znovu."
                }
                return copy
            }
        }
    }
    func save() {
        do {
            try FileManager.default.createDirectory(at: historyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(jobs)
            try data.write(to: historyURL, options: .atomic)
        } catch { message = "Historii nelze uložit: \(error.localizedDescription)" }
    }
    func enqueue(text: String, profile: DownloadProfile, playlist: Bool, folder: String, trimStart: Double? = nil, trimEnd: Double? = nil) {
        do {
            let urls = try DownloadCommand.validatedURLs(text)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: folder, isDirectory: &isDirectory), isDirectory.boolValue,
                  FileManager.default.isWritableFile(atPath: folder) else {
                throw DownloadCommand.InputError.invalid("Vyberte existující složku, do které lze zapisovat.")
            }
            tools = .current
            guard tools.ready else { throw DownloadCommand.InputError.invalid("Chybí yt-dlp, FFmpeg nebo ffprobe. Otevřete sekci Nástroje.") }
            jobs.insert(contentsOf: urls.reversed().map { DownloadJob(url: $0, profile: profile, playlist: playlist, folder: folder, trimStart: trimStart, trimEnd: trimEnd) }, at: 0)
            save(); startNext()
        } catch { message = error.localizedDescription }
    }
    func enqueueMedia(_ items: [MediaItem], profile: DownloadProfile, selector: String?, subtitles: String?, imageOptions: ImageOptions, folder: String, trimStart: Double? = nil, trimEnd: Double? = nil) {
        guard FileManager.default.isWritableFile(atPath:folder) else { message = "Cílová složka není zapisovatelná."; return }
        for item in items {
            guard (try? DownloadCommand.validatedURLs(item.url)) != nil else { continue }
            let itemProfile = item.kind == .audio && !profile.isAudio ? DownloadProfile.audio[0] : profile
            var job = DownloadJob(url:item.url,profile:itemProfile,playlist:false,folder:folder)
            job.displayTitle = item.title; job.referer = item.referer
            job.formatSelector = selector; job.subtitleLanguage = subtitles
            if item.kind == .image { job.imageOptions = imageOptions }
            else { job.trimStart = trimStart; job.trimEnd = trimEnd }
            jobs.insert(job,at:0)
        }
        save(); startNext()
    }
    func enableNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options:[.alert,.sound]) { allowed,_ in
            UserDefaults.standard.set(allowed,forKey:"notifications")
        }
    }
    private func notify(_ job: DownloadJob) {
        guard UserDefaults.standard.bool(forKey:"notifications") else { return }
        let content = UNMutableNotificationContent(); content.title = job.state == .finished ? "Stažení dokončeno" : "Stažení vyžaduje pozornost"
        content.body = job.displayTitle ?? job.profile.title; content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier:job.id.uuidString,content:content,trigger:nil))
    }
    func startNext() {
        guard !busy, !paused, let index = jobs.indices.reversed().first(where: { jobs[$0].state == .queued }) else { return }
        tools = .current
        let jobToStart = jobs[index]
        if let options = jobToStart.imageOptions {
            activeID = jobToStart.id; jobs[index].state = .running; jobs[index].detail = "Stahuji a zpracovávám obrázek…"
            imageTask = Task {
                do {
                    let path = try await ImageDownload.run(url:jobToStart.url,referer:jobToStart.referer,folder:jobToStart.folder,title:jobToStart.displayTitle ?? "Obrázek",options:options)
                    if let i = jobs.firstIndex(where: { $0.id == jobToStart.id }) { jobs[i].files.append(path) }
                    finish(id:jobToStart.id,code:0,cancelled:false)
                } catch {
                    if let i = jobs.firstIndex(where: { $0.id == jobToStart.id }) { jobs[i].log = error.localizedDescription }
                    finish(id:jobToStart.id,code:1,cancelled:Task.isCancelled)
                }
            }
            return
        }
        guard let yt = tools.downloader, let ff = tools.ffmpeg, tools.ready else { message = "Potřebné nástroje nejsou dostupné."; return }
        jobs[index].state = .running
        jobs[index].detail = "Načítám informace…"
        let job = jobs[index]; activeID = job.id
        let process = ProcessRunner(); runner = process
        Task {
        let cookieFile = await BrowserSession.export(for:job.url)
        var arguments = DownloadCommand.arguments(for:job,ffmpeg:ff)
        if let cookieFile { arguments.insert(contentsOf:["--cookies",cookieFile.path],at:0) }
        process.run(executable: yt, arguments: arguments, line: { [weak self] line in
            DispatchQueue.main.async { self?.receive(line, id: job.id) }
        }, completion: { [weak self] code, cancelled in
            if let cookieFile { try? FileManager.default.removeItem(at:cookieFile) }
            DispatchQueue.main.async { self?.downloadFinished(id: job.id, code: code, cancelled: cancelled) }
        })
        }
    }
    private func downloadFinished(id: UUID, code: Int32, cancelled: Bool) {
        guard !cancelled, code == 0, let job = jobs.first(where: { $0.id == id }),
              job.profile.format == "mp4", job.imageOptions == nil, !job.files.isEmpty,
              let ffmpeg = tools.ffmpeg, let ffprobe = tools.ffprobe else {
            finish(id: id, code: code, cancelled: cancelled); return
        }
        let conversion = ProcessRunner(); runner = conversion
        if let i = jobs.firstIndex(where: { $0.id == id }) {
            jobs[i].conversionStage = "Kontrola videa"
            jobs[i].conversionProgress = nil
            jobs[i].detail = "Ověřuji a připravuji video pro přehrávač Apple…"
        }
        Task {
            do {
                for (fileIndex, path) in job.files.enumerated() {
                    try await AppleVideoCompatibility.prepare(path, ffmpeg: ffmpeg, ffprobe: ffprobe, runner: conversion, progress: { [weak self] progress in
                        DispatchQueue.main.async {
                            guard let self, let i = self.jobs.firstIndex(where: { $0.id == id }), self.jobs[i].state == .running else { return }
                            let prefix = job.files.count > 1 ? "Soubor \(fileIndex + 1)/\(job.files.count) · " : ""
                            switch progress {
                            case .checking:
                                self.jobs[i].conversionStage = "Kontrola videa"
                                self.jobs[i].conversionProgress = nil
                                self.jobs[i].detail = prefix + "Kontroluji kompatibilitu videa…"
                            case .converting(let value):
                                self.jobs[i].conversionStage = "Převádí se"
                                self.jobs[i].conversionProgress = value
                                self.jobs[i].detail = prefix + "Převod pro Apple" + (value.map { " · \(Int($0 * 100)) %" } ?? "…")
                            case .finalizing:
                                self.jobs[i].conversionStage = "Dokončuji převod"
                                self.jobs[i].conversionProgress = nil
                                self.jobs[i].detail = prefix + "Ověřuji a ukládám výsledné video…"
                            }
                        }
                    }) { [weak self] line in
                        DispatchQueue.main.async { self?.receive(line, id: id) }
                    }
                }
                finish(id: id, code: 0, cancelled: false)
            } catch {
                receive(error.localizedDescription, id: id)
                finish(id: id, code: 1, cancelled: error is CancellationError)
            }
        }
    }
    private func receive(_ line: String, id: UUID) {
        guard let i = jobs.firstIndex(where: { $0.id == id }) else { return }
        if line.hasPrefix("UDP_PROGRESS|") {
            let parts = line.components(separatedBy: "|")
            if parts.count >= 4 {
                let number = parts[1].replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
                if let value = Double(number) { jobs[i].progress = min(1, max(0, value / 100)) }
                jobs[i].detail = "\(parts[1]) · \(parts[2]) · zbývá \(parts[3])"
            }
        } else if line.hasPrefix("UDP_FILE|") {
            let raw = String(line.dropFirst(9))
            if let data = raw.data(using: .utf8), let path = try? JSONDecoder().decode(String.self, from: data),
               FileManager.default.fileExists(atPath: path), !jobs[i].files.contains(path) { jobs[i].files.append(path) }
        } else {
            if line.hasPrefix("UDP_TITLE|") { jobs[i].detail = String(line.dropFirst(10)); jobs[i].progress = 0 }
            else if line.hasPrefix("[ExtractAudio]") || line.hasPrefix("[Merger]") || line.hasPrefix("[VideoRemuxer]") { jobs[i].detail = "Zpracovávám výsledný soubor…" }
            jobs[i].log += line + "\n"
            if jobs[i].log.count > 30000 { jobs[i].log = String(jobs[i].log.suffix(30000)) }
        }
    }
    private func finish(id: UUID, code: Int32, cancelled: Bool) {
        if let i = jobs.firstIndex(where: { $0.id == id }) {
            jobs[i].conversionStage = nil; jobs[i].conversionProgress = nil
            if cancelled { jobs[i].state = .cancelled; jobs[i].detail = "Stahování zrušeno. Rozpracované soubory zůstaly pro opakování." }
            else if code == 0 && !jobs[i].files.isEmpty {
                jobs[i].state = .finished; jobs[i].progress = 1
                jobs[i].detail = "Uloženo souborů: \(jobs[i].files.count)"
            } else {
                jobs[i].state = .failed
                jobs[i].detail = "\(jobs[i].files.isEmpty ? "Stažení se nezdařilo" : "Dokončeno jen částečně") (kód \(code)). Podrobnosti v protokolu."
            }
        }
        if let job = jobs.first(where: { $0.id == id }), !cancelled { notify(job) }
        runner = nil; activeID = nil; save(); startNext()
    }
    func cancel(_ id: UUID) {
        if activeID == id { runner?.cancel(); imageTask?.cancel() }
        else if let i = jobs.firstIndex(where: { $0.id == id }), jobs[i].state == .queued {
            jobs[i].state = .cancelled; jobs[i].detail = "Odebráno z fronty"; save()
        }
    }
    func retry(_ job: DownloadJob) { var copy = job; copy.id = UUID(); copy.state = .queued; copy.progress = 0; copy.conversionStage = nil; copy.conversionProgress = nil; copy.files = []; copy.log = ""; copy.detail = "Čeká na spuštění"; jobs.insert(copy,at:0); save(); startNext() }
    func removeFromHistory(_ id: UUID) {
        guard let job = jobs.first(where: { $0.id == id }), job.state != .queued, job.state != .running else { return }
        jobs.removeAll { $0.id == id }
        save()
    }
    func clearHistory() {
        jobs.removeAll { $0.state != .queued && $0.state != .running }
        save()
    }
    func togglePause() { paused.toggle(); if !paused { startNext() } }
    func maintain(install: Bool) {
        guard !busy else { return }
        tools = .current
        guard let brew = tools.brew else { message = "Nejprve nainstalujte Homebrew z brew.sh. Poté zde lze nainstalovat potřebné nástroje."; return }
        maintenance = true; maintenanceLog = install ? "Instaluji yt-dlp a FFmpeg…\n" : "Aktualizuji yt-dlp…\n"
        let process = ProcessRunner(); runner = process
        process.run(executable: brew, arguments: install ? ["install", "yt-dlp", "ffmpeg", "gallery-dl"] : ["upgrade", "yt-dlp", "gallery-dl"], line: { [weak self] line in
            DispatchQueue.main.async {
                guard let self else { return }; self.maintenanceLog += line + "\n"
                if self.maintenanceLog.count > 30000 { self.maintenanceLog = String(self.maintenanceLog.suffix(30000)) }
            }
        }, completion: { [weak self] code, cancelled in
            DispatchQueue.main.async {
                guard let self else { return }
                self.maintenanceLog += cancelled ? "\nZrušeno." : code == 0 ? "\nHotovo." : "\nOperace selhala (\(code))."
                self.maintenance = false; self.runner = nil; self.tools = .current; self.startNext()
            }
        })
    }
    func stopMaintenance() { runner?.cancel() }
    func stopForQuit() { paused = true; runner?.cancel(); imageTask?.cancel(); save() }
}
