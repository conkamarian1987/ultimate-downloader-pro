#!/usr/bin/env python3
from pathlib import Path
import subprocess, tempfile
repo=Path(__file__).resolve().parents[1]
source=(repo/'Sources/AppFeatures.swift').read_text().split('import Sparkle')[1]
code='import AppKit\nimport Sparkle\n@MainActor final class DownloadStore { var busy=false; var waitingCount=0; var saves=0; func save() { saves += 1 } }\n'+source
code += 'extension AppUpdates {\n static func testDeferral() async {\n  let store = DownloadStore()\n  let updater = AppUpdates()\n  updater.store = store\n  var installs = 0\n  store.busy = true\n  updater.deferInstallation { installs += 1 }\n  try? await Task.sleep(for: .milliseconds(1150))\n  precondition(installs == 0, "Installed during active work")\n  store.busy = false; store.waitingCount = 1\n  try? await Task.sleep(for: .milliseconds(1150))\n  precondition(installs == 0, "Installed with a queued/paused job")\n  store.waitingCount = 0\n  try? await Task.sleep(for: .milliseconds(1150))\n  precondition(installs == 1 && store.saves == 1, "Failed to install once when idle")\n  try? await Task.sleep(for: .milliseconds(1150))\n  precondition(installs == 1, "Installed twice")\n  print("PASS: busy, queued, idle, exactly-once installation")\n }\n}\n@main struct Tests { @MainActor static func main() async { await AppUpdates.testDeferral() } }\n'
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp); (p/'test.swift').write_text(code)
 frameworks=str(repo/'Frameworks')
 subprocess.run(['swiftc','-parse-as-library','-F',frameworks,'-framework','Sparkle','-Xlinker','-rpath','-Xlinker',frameworks,'-module-cache-path',str(p/'cache'),str(p/'test.swift'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
