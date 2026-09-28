#!/usr/bin/env python3
"""Package and sign a built app. Never exports or prints the private key."""
from pathlib import Path
import argparse, json, plistlib, re, subprocess
ROOT = Path(__file__).resolve().parents[1]
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('app', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--key', type=Path, default=Path.home()/'Library/Application Support/UltimateDownloaderSigning/ed25519.key')
    parser.add_argument('--sign-tool', type=Path, default=ROOT/'.build-tools/Sparkle/sign_update')
    args = parser.parse_args()
    info = plistlib.loads((args.app/'Contents/Info.plist').read_bytes())
    version = info['CFBundleShortVersionString']
    if not re.fullmatch(r'[0-9]+(?:\.[0-9]+){1,3}', version): raise SystemExit('Invalid version')
    if not info.get('SUPublicEDKey'): raise SystemExit('Missing public key in app')
    subprocess.run(['codesign','--verify','--deep','--strict',str(args.app)],check=True)
    args.output.mkdir(parents=True, exist_ok=True)
    archive = args.output/f'UltimateDownloaderPro-{version}.zip'
    if archive.exists(): raise SystemExit('Refusing to overwrite an existing release archive')
    subprocess.run(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(args.app),str(archive)],check=True)
    signature = subprocess.check_output([str(args.sign_tool),'--ed-key-file',str(args.key),'-p',str(archive)],text=True).strip()
    subprocess.run([str(args.sign_tool),'--ed-key-file',str(args.key),'--verify',str(archive),signature],check=True)
    manifest = {'archive':archive.name,'signature':signature,'version':version,'build':str(info['CFBundleVersion'])}
    (args.output/'update-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'Ready: {archive.name} and update-manifest.json; publish BOTH as GitHub release assets.')
if __name__ == '__main__': main()
