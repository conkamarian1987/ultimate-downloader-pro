#!/usr/bin/env python3
"""Exercise the real Sparkle user driver with current, offline and incompatible feeds."""
from pathlib import Path
import plistlib, subprocess, tempfile
repo = Path(__file__).resolve().parents[1]
source = (repo/'Sources/AppFeatures.swift').read_text().split('import Sparkle')[1]
code = 'import SwiftUI\nimport Sparkle\nimport UserNotifications\n@MainActor final class DownloadStore { var updatesBlocked=true; var busy=false; var waitingCount=0; var stops=0; var saves=0; func save() { saves += 1 }; func stopForQuit() { stops += 1 } }\n' + source
code += '\nfinal class AppDelegate' + (repo/'Sources/UltimateDownloaderApp.swift').read_text().split('final class AppDelegate')[1]
code += r"""
extension AppUpdates {
 static func runTests() async {
  func item(_ version: String) -> SUAppcastItem {
   SUAppcastItem(dictionary: ["title":"Test", "enclosure":["url":"https://example.com/app.zip", "sparkle:version":version, "length":"100", "type":"application/octet-stream"]])!
  }
  func result(_ reason: Int, _ version: String?) -> NSError {
   var info: [String:Any] = [SPUNoUpdateFoundReasonKey: reason]
   if let version { info[SPULatestAppcastItemFoundKey] = item(version) }
   return NSError(domain:SUSparkleErrorDomain,code:1001,userInfo:info)
  }
  for (reason, version, allowed) in [(1,"11",true),(2,"10",true),(1,"12",false),(3,"12",false),(4,"12",false),(5,"12",false),(0,"11",false)] {
   let gate=AppUpdates(); let store=DownloadStore();gate.store=store
   var ack=0
   gate.showUpdateNotFoundWithError(result(reason,version)) { ack += 1 }
   precondition(gate.unlocked == allowed && store.updatesBlocked == !allowed && ack == 1)
   gate.dismissUpdateInstallation()
   precondition(gate.unlocked == allowed)
  }
  let gate=AppUpdates()
  gate.showUpdateNotFoundWithError(result(1,nil)) {}
  precondition(!gate.unlocked,"Empty feed unlocked app")
  gate.showUpdaterError(NSError(domain:NSURLErrorDomain,code:-1009)) {}
  precondition(!gate.unlocked,"Offline unlocked app")
  gate.dismissUpdateInstallation(); precondition(!gate.unlocked)
  var installs=0
  gate.installReply = { choice in precondition(choice == .install); installs += 1 }
  gate.install();gate.install();precondition(installs == 1 && !gate.unlocked)
  var ready=0
  gate.showReady(toInstallAndRelaunch: { choice in precondition(choice == .install);ready += 1 })
  precondition(ready == 1 && !gate.unlocked)
  let handoff=AppUpdates();let handoffStore=DownloadStore();handoff.store=handoffStore
  var quits=0;handoff.requestTermination = { quits += 1 }
  handoff.showReady(toInstallAndRelaunch: { precondition($0 == .install) })
  precondition(!handoff.installationReadyToQuit && quits == 0, "Quit before installer was ready")
  handoff.showInstallingUpdate(withApplicationTerminated:false,retryTerminatingApplication:{ preconditionFailure("Unexpected repeated installation") })
  handoff.showInstallingUpdate(withApplicationTerminated:false,retryTerminatingApplication:{})
  await handoff.terminationTask?.value
  precondition(quits == 1 && handoff.installationReadyToQuit, "Ready installer must close old app exactly once")
  let delegate=AppDelegate();delegate.store=handoffStore;delegate.updates=handoff
  handoffStore.busy=true;handoffStore.waitingCount=1
  precondition(delegate.prepareForUpdateTermination() && handoffStore.stops == 1, "Update must save/stop without another confirmation")
  delegate.updates=nil
  precondition(!delegate.prepareForUpdateTermination() && handoffStore.stops == 1, "Ordinary quit must keep its normal confirmation")
  let aborted=AppUpdates();var abortQuits=0;aborted.requestTermination = { abortQuits += 1 }
  aborted.showInstallingUpdate(withApplicationTerminated:false,retryTerminatingApplication:{})
  let pending=aborted.terminationTask
  aborted.showUpdaterError(NSError(domain:SUSparkleErrorDomain,code:4000)) {}
  await pending?.value
  precondition(abortQuits == 0 && !aborted.installationReadyToQuit, "Error must cancel pending exit")
  let alreadyClosed=AppUpdates();var closedQuits=0;alreadyClosed.requestTermination = { closedQuits += 1 }
  alreadyClosed.showInstallingUpdate(withApplicationTerminated:true,retryTerminatingApplication:{})
  precondition(!alreadyClosed.installationReadyToQuit && closedQuits == 0)
  let nextLaunch=AppUpdates();precondition(!nextLaunch.unlocked)
  print("PASS: current/newer, required/incompatible, empty feed, offline, dismissal, exactly-once install, relaunch locked; install handoff ordering, exactly-once quit, abort cancellation")
 }
}
@main struct Tests { @MainActor static func main() async { await AppUpdates.runTests() } }
"""
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp); app=p/'GateTests.app/Contents'; (app/'MacOS').mkdir(parents=True)
 (app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'test.downloader.gate','CFBundleExecutable':'GateTests','CFBundleVersion':'11','CFBundlePackageType':'APPL'}))
 (p/'test.swift').write_text(code)
 frameworks=str(repo/'Frameworks')
 subprocess.run(['swiftc','-parse-as-library','-F',frameworks,'-framework','Sparkle','-Xlinker','-rpath','-Xlinker',frameworks,'-module-cache-path',str(p/'cache'),str(p/'test.swift'),'-o',str(app/'MacOS/GateTests')],check=True)
 subprocess.run([str(app/'MacOS/GateTests')],check=True)
