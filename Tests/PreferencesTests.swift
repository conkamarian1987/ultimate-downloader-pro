import Foundation
@main struct PreferencesTests {
    @MainActor static func main() throws {
        precondition(MediaOptionsView.seconds("1:02:03.5") == 3723.5)
        precondition(MediaOptionsView.seconds("1,5") == 1.5)
        for invalid in ["", "-1", "NaN", "inf", "1:60", "1::3", "1:2:3:4"] { precondition(MediaOptionsView.seconds(invalid) == nil) }
        let preset = SavedMediaPreset(name: "Moje hudba", output: "audio", profileID: "mp3-192", container: "mp4", imageFormat: "jpeg", dimension: 1920)
        let data = try JSONEncoder().encode([preset])
        let decoded = try JSONDecoder().decode([SavedMediaPreset].self, from: data)
        precondition(decoded[0].profileID == "mp3-192" && decoded[0].id == preset.id && decoded[0].dimension == 1920)
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(DownloadJob(url: "https://example.com/video", profile: .video[0], playlist: false, folder: "/tmp"))) as! [String: Any]
        legacy.removeValue(forKey: "trimStart"); legacy.removeValue(forKey: "trimEnd")
        let old = try JSONDecoder().decode(DownloadJob.self, from: JSONSerialization.data(withJSONObject: legacy))
        precondition(old.trimStart == nil && old.trimEnd == nil)
        print("PASS time parsing, invalid times, favorite profile persistence, legacy history")
    }
}
