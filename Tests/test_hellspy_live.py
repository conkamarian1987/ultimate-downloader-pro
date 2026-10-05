#!/usr/bin/env python3
"""Optional live test; downloads the freely distributed Big Buck Bunny test video."""
import pathlib, subprocess, tempfile, sys
root = pathlib.Path(__file__).resolve().parents[1]
source = (root/'Sources/HellspyService.swift').read_text()
stub = '''\nenum DownloadCommand { enum InputError: LocalizedError { case invalid(String); var errorDescription: String? { if case .invalid(let s) = self { return s }; return nil } } }\n'''
harness = r'''
@main struct Verify {
 static func main() async throws {
    let results = try await HellspyAPI.search("Big Buck Bunny", offset: 0).items
    precondition(!results.isEmpty)
    let video = results.first(where: { $0.id == 2461091 }) ?? results[0]
    let detail = try await HellspyAPI.detail(id: video.id, hash: video.fileHash)
    precondition(!detail.qualities.isEmpty)
    let quality = detail.qualities.last!
    let ref = HellspyReference(id: video.id, fileHash: video.fileHash, quality: quality)
    let path = try await HellspyAPI.download(ref, folder: CommandLine.arguments[1], title: "Big Buck Bunny validation", progress: { _ in })
    print("PASS live search=\(results.count), quality=\(quality), downloaded=\(path)")
 }
}
'''
with tempfile.TemporaryDirectory(prefix='udp-hellspy-') as tmp:
 p=pathlib.Path(tmp); (p/'Check.swift').write_text(source+stub+harness)
 subprocess.run(['xcrun','swiftc','-parse-as-library','-module-cache-path','/tmp/udp-vlc-module-cache',str(p/'Check.swift'),'-o',str(p/'check')],check=True)
 subprocess.run([str(p/'check'),str(pathlib.Path(sys.argv[1]).resolve())],check=True,timeout=180)
