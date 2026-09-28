#!/usr/bin/env python3
"""Fetch the pinned upstream binary. No private keys are needed for building."""
from pathlib import Path
import hashlib, subprocess, tempfile, urllib.request
ROOT = Path(__file__).resolve().parents[1]
URL = 'https://github.com/sparkle-project/Sparkle/releases/download/2.10.0/Sparkle-2.10.0.tar.xz'
SHA256 = 'c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c'
def main():
    destination = ROOT / 'Frameworks/Sparkle.framework'
    with tempfile.TemporaryDirectory() as tmp:
        archive = Path(tmp) / 'Sparkle.tar.xz'
        urllib.request.urlretrieve(URL, archive)
        if hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
            raise SystemExit('Sparkle checksum mismatch')
        subprocess.run(['tar', '-xf', str(archive), '-C', tmp], check=True)
        destination.parent.mkdir(exist_ok=True)
        subprocess.run(['ditto', str(Path(tmp)/'Sparkle.framework'), str(destination)], check=True)
        tools = ROOT / '.build-tools/Sparkle'
        tools.mkdir(parents=True, exist_ok=True)
        subprocess.run(['ditto', str(Path(tmp)/'bin'), str(tools)], check=True)
        print('Sparkle 2.10.0 verified and installed locally.')
if __name__ == '__main__': main()
