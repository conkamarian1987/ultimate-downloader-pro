#!/usr/bin/env python3
"""Install the pinned, unmodified official VLCKit framework for macOS."""
from pathlib import Path
import hashlib, subprocess, tempfile, urllib.request
ROOT = Path(__file__).resolve().parents[1]
URL = 'https://download.videolan.org/pub/cocoapods/prod/VLCKit-3.7.2-3e42ae47-79128878.tar.xz'
SHA256 = '45fc6398c80d1f8dc0e384a9c80704848e9e82a3a382611bf531fa83c198c276'
with tempfile.TemporaryDirectory() as tmp:
    archive = Path(tmp)/'VLCKit.tar.xz'
    urllib.request.urlretrieve(URL, archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
        raise SystemExit('VLCKit checksum mismatch')
    subprocess.run(['tar','-xf',str(archive),'-C',tmp],check=True)
    source = Path(tmp)/'VLCKit - binary package/VLCKit.xcframework/macos-arm64_x86_64/VLCKit.framework'
    (ROOT/'Frameworks').mkdir(exist_ok=True)
    subprocess.run(['ditto',str(source),str(ROOT/'Frameworks/VLCKit.framework')],check=True)
    print('VLCKit 3.7.2 verified and installed.')
