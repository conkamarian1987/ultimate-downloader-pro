#!/usr/bin/env python3
"""Real throttled HTTP downloads: known/unknown length, progress, rate and cancellation."""
from pathlib import Path
import http.server, threading, time, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
class Server(http.server.BaseHTTPRequestHandler):
 def log_message(self,*args): pass
 def do_GET(self):
  self.send_response(200)
  if self.path != '/unknown': self.send_header('Content-Length',str(64*32768))
  self.end_headers()
  try:
   for _ in range(64): self.wfile.write(b'x'*32768); self.wfile.flush(); time.sleep(.025)
  except (BrokenPipeError,ConnectionResetError): pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Server)
threading.Thread(target=server.serve_forever,daemon=True).start()
source=(root/'Sources/HellspyService.swift').read_text()
stub='enum DownloadCommand { enum InputError: LocalizedError { case invalid(String); var errorDescription: String? { if case .invalid(let s) = self { return s }; return nil } } }'
harness=r'''
final class Samples: @unchecked Sendable {
 let lock = NSLock(); var values: [TransferProgress] = []
 func add(_ value: TransferProgress) { lock.lock(); values.append(value); lock.unlock() }
 func get() -> [TransferProgress] { lock.lock(); defer { lock.unlock() }; return values }
}
@main struct Test {
 static func main() async throws {
    let base = CommandLine.arguments[1]
    for endpoint in ["known", "unknown"] {
        let samples = Samples()
        let transfer = VideoDownloadTransfer { samples.add($0) }
        let (file, _) = try await transfer.download(URL(string: base + endpoint)!)
        defer { try? FileManager.default.removeItem(at: file) }
        let values = samples.get()
        precondition(values.count >= 2, "No live progress callbacks")
        precondition(values.allSatisfy { $0.bytesPerSecond > 0 })
        precondition(values.first!.received < values.last!.received)
        if endpoint == "known" {
            precondition(values.contains { ($0.fraction ?? 0) > 0 && ($0.fraction ?? 1) < 1 })
            precondition(values.last!.fraction == 1)
        } else { precondition(values.allSatisfy { $0.fraction == nil }) }
        print("PASS \(endpoint): \(values.count) updates; \(values.last!.detail)")
    }
    let transfer = VideoDownloadTransfer { _ in }
    let task = Task { try await transfer.download(URL(string: base + "cancel")!) }
    try await Task.sleep(for: .milliseconds(200)); task.cancel()
    do { let (file, _) = try await task.value; try? FileManager.default.removeItem(at: file); fatalError("Cancellation ignored") }
    catch is CancellationError { print("PASS cancellation") }
 }
}
'''
try:
 with tempfile.TemporaryDirectory() as tmp:
  p=Path(tmp);(p/'test.swift').write_text(source+'\n'+stub+'\n'+harness)
  subprocess.run(['xcrun','swiftc','-parse-as-library','-module-cache-path','/tmp/udp-vlc-module-cache',str(p/'test.swift'),'-o',str(p/'test')],check=True)
  subprocess.run([str(p/'test'),f'http://127.0.0.1:{server.server_port}/'],check=True,timeout=15)
finally: server.shutdown()
