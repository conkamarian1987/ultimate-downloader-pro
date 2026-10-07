from pathlib import Path
import plistlib,subprocess,shutil,json,http.server,threading,os,time
import argparse
parser=argparse.ArgumentParser(description="Prepare an isolated, signed Sparkle install/relaunch fixture and serve it on localhost.")
parser.add_argument('--work-dir',type=Path,required=True)
parser.add_argument('--renamed-candidate',action='store_true',help='Test a renamed candidate with the same bundle identifier.')
parser.add_argument('--key',type=Path,default=Path.home()/'Library/Application Support/UltimateDownloaderSigning/ed25519.key')
args=parser.parse_args()
root=Path(__file__).resolve().parents[1];work=args.work_dir.resolve()
if work.exists():raise SystemExit('Use a new work directory; existing files will not be overwritten.')
work.mkdir(parents=True)

server=http.server.ThreadingHTTPServer(('127.0.0.1',0),lambda *a,**k:http.server.SimpleHTTPRequestHandler(*a,directory=str(work),**k));port=server.server_address[1]
source='''import SwiftUI
import Sparkle
import UserNotifications
@MainActor func record(_ event: String) {
 let line = "\\(ProcessInfo.processInfo.processIdentifier) \\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?") \\(event)\\n"
 let url=URL(fileURLWithPath: LOG_PATH)
 if !FileManager.default.fileExists(atPath:url.path) { FileManager.default.createFile(atPath:url.path,contents:nil) }
 if let f=try? FileHandle(forWritingTo:url) { try? f.seekToEnd();try? f.write(contentsOf:Data(line.utf8));try? f.close() }
}
@MainActor final class DownloadStore { var updatesBlocked=true;var busy=false;var waitingCount=0;func save(){ record("saved") };func stopForQuit(){record("quit-approved")} }
'''.replace('LOG_PATH',json.dumps(str(work/'events.log')))
source+=(root/'Sources/AppFeatures.swift').read_text().split('import Sparkle')[1]
source+='\nfinal class AppDelegate'+(root/'Sources/UltimateDownloaderApp.swift').read_text().split('final class AppDelegate')[1]
source+='''
struct TestRoot: View {
 @ObservedObject var updates:AppUpdates
 var body:some View {
  if updates.unlocked { Text("Test instalace dokončen – verze " + (Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "?")).padding(40) }
  else { RequiredUpdateView().environmentObject(updates) }
 }
}
@main struct Probe {
 @MainActor static func main() {
  let app=NSApplication.shared;app.setActivationPolicy(.regular)
  let delegate=AppDelegate();let store=DownloadStore();let updates=AppUpdates()
  delegate.store=store;delegate.updates=updates;app.delegate=delegate
  let window=NSWindow(contentRect:NSRect(x:0,y:0,width:720,height:450),styleMask:[.titled,.closable],backing:.buffered,defer:false)
  window.title="Test instalace Downloaderu";window.contentView=NSHostingView(rootView:TestRoot(updates:updates));window.center();window.makeKeyAndOrderFront(nil)
  record("started")
  let observation=updates.$status.sink { record("status: " + $0) }
  DispatchQueue.main.async { updates.connect(to:store) }
  withExtendedLifetime((delegate,store,updates,window,observation)) { app.run() }
 }
}
'''
(work/'probe.swift').write_text(source);subprocess.run(['swiftc','-parse-as-library','-F',str(root/'Frameworks'),'-framework','Sparkle','-Xlinker','-rpath','-Xlinker','@executable_path/../Frameworks','-module-cache-path',str(work/'cache'),str(work/'probe.swift'),'-o',str(work/'InstallProbe')],check=True)
for version,subdir in [('1','installed'),('2','candidate')]:
 app=work/subdir/('Encore.app' if args.renamed_candidate and version=='2' else 'InstallProbe.app');(app/'Contents/MacOS').mkdir(parents=True,exist_ok=True);(app/'Contents/Frameworks').mkdir(exist_ok=True);(app/'Contents/Resources').mkdir(exist_ok=True)
 shutil.copy2(work/'InstallProbe',app/'Contents/MacOS/InstallProbe');shutil.copytree(root/'Frameworks/Sparkle.framework',app/'Contents/Frameworks/Sparkle.framework',symlinks=True,dirs_exist_ok=True)
 info=plistlib.loads((root/'Info.plist').read_bytes());info.update(CFBundleExecutable='InstallProbe',CFBundleIdentifier='cz.ultimate.installprobe',CFBundleName=('Encore' if args.renamed_candidate and version=='2' else 'Ultimate Downloader Pro'),CFBundleDisplayName=('Encore Migration Test' if args.renamed_candidate and version=='2' else 'Test instalace Downloaderu'),CFBundleVersion=version,CFBundleShortVersionString='1.0.'+version,SUFeedURL=f'http://127.0.0.1:{port}/appcast.xml',NSAppTransportSecurity={'NSAllowsLocalNetworking':True,'NSAllowsArbitraryLoads':True});info.pop('CFBundleURLTypes',None)
 (app/'Contents/Info.plist').write_bytes(plistlib.dumps(info));(app/'Contents/Resources'/('old-only.txt' if version=='1' else 'new-only.txt')).write_text(version)
 subprocess.run(['codesign','--force','--deep','--sign','-',str(app)],check=True)
 subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
archive=work/'update.zip';subprocess.run(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(work/'candidate'/('Encore.app' if args.renamed_candidate else 'InstallProbe.app')),str(archive)],check=True)
sig=subprocess.check_output([str(root/'.build-tools/Sparkle/sign_update'),'--ed-key-file',str(args.key),'-p',str(archive)],text=True).strip()
(work/'appcast.xml').write_text(f'''<?xml version="1.0"?><rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><title>Local installation test</title><item><title>Test 2</title><sparkle:version>2</sparkle:version><sparkle:shortVersionString>1.0.2</sparkle:shortVersionString><enclosure url="http://127.0.0.1:{port}/update.zip" length="{archive.stat().st_size}" type="application/octet-stream" sparkle:edSignature="{sig}"/></item></channel></rss>''')
print('READY',work/'installed/InstallProbe.app','port',port,flush=True)
server.serve_forever()
