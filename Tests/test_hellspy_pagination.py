#!/usr/bin/env python3
"""Exercise the real browser model with server-style cursors, short pages and duplicates."""
from pathlib import Path
import subprocess, tempfile
root=Path(__file__).resolve().parents[1]
service=(root/'Sources/HellspyService.swift').read_text()
model=(root/'Sources/HellspyView.swift').read_text().split('struct HellspyView: View')[0]
stub='enum DownloadCommand { enum InputError: LocalizedError { case invalid(String); var errorDescription: String? { if case .invalid(let s) = self { return s }; return nil } } }'
harness=r'''
@main struct Test {
 @MainActor static func main() async throws {
    let video = HellspyVideo(id: 1, title: "one", fileHash: "a", size: nil, duration: nil, thumbs: nil)
    let other = HellspyVideo(id: 2, title: "two", fileHash: "b", size: nil, duration: nil, thumbs: nil)
    var offsets: [Int] = []
    let browser = HellspyBrowser { _, offset in
        offsets.append(offset)
        if offset == 0 { return HellspyPage(items: [video], nextOffset: 1000063) }
        precondition(offset == 1000063)
        return HellspyPage(items: [video, other], nextOffset: nil)
    }
    browser.query = "test"; browser.search()
    try await Task.sleep(for: .milliseconds(100))
    precondition(browser.more && browser.videos.count == 1, "Short page with cursor was dropped")
    browser.search(next: true); browser.search(next: true)
    try await Task.sleep(for: .milliseconds(100))
    precondition(offsets == [0,1000063], "Wrong cursor or overlapping requests")
    precondition(browser.videos.map(\.id) == [1,2] && !browser.more, "Duplicate or wrong end-of-results")
    browser.search(next: true)
    precondition(offsets.count == 2)
    print("PASS: server cursor, short page, deduplication, request guard, end of results")
 }
}
'''
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp); (p/'test.swift').write_text(service+'\n'+model+'\n'+stub+'\n'+harness)
 subprocess.run(['xcrun','swiftc','-parse-as-library','-module-cache-path','/tmp/udp-vlc-module-cache',str(p/'test.swift'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
