#!/usr/bin/env python3
"""Validate a signed release archive with the repository's public key, then update the feed."""
from pathlib import Path
import argparse, base64, json, os, plistlib, re, subprocess, tempfile, urllib.parse, xml.etree.ElementTree as ET, zipfile
ROOT = Path(__file__).resolve().parents[1]
NS='http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', NS)
def main():
    p=argparse.ArgumentParser();p.add_argument('assets',type=Path);p.add_argument('tag');p.add_argument('--feed',type=Path,default=ROOT/'updates/appcast.xml');a=p.parse_args()
    manifest=json.loads((a.assets/'update-manifest.json').read_text())
    name=manifest['archive']
    if not re.fullmatch(r'(?:UltimateDownloaderPro|Encore)-[0-9.]+\.zip',name):raise SystemExit('Invalid asset name')
    archive=a.assets/name
    public=plistlib.loads((ROOT/'Info.plist').read_bytes())['SUPublicEDKey']
    key=base64.b64decode(public,validate=True);signature=base64.b64decode(manifest['signature'],validate=True)
    if len(key)!=32 or len(signature)!=64:raise SystemExit('Invalid signature encoding')
    with tempfile.TemporaryDirectory() as tmp:
        pub=Path(tmp)/'public.der';sig=Path(tmp)/'signature'
        pub.write_bytes(bytes.fromhex('302a300506032b6570032100')+key);sig.write_bytes(signature)
        subprocess.run([os.environ.get('OPENSSL','openssl'),'pkeyutl','-verify','-pubin','-keyform','DER','-inkey',str(pub),'-rawin','-in',str(archive),'-sigfile',str(sig)],check=True)
    with zipfile.ZipFile(archive) as z:
        infos=[n for n in z.namelist() if re.fullmatch(r'[^/]+\.app/Contents/Info.plist',n)]
        if len(infos)!=1:raise SystemExit('Archive must contain exactly one root app')
        info=plistlib.loads(z.read(infos[0]))
    if info['CFBundleIdentifier']!='cz.ultimate.downloaderpro' or info.get('SUPublicEDKey')!=public:raise SystemExit('Wrong app identity or signing key')
    version=info['CFBundleShortVersionString'];build=str(info['CFBundleVersion'])
    if not re.fullmatch(r'[0-9]+(?:\.[0-9]+){1,3}',version) or not build.isdigit():raise SystemExit('Invalid version')
    if a.tag!='v'+version or manifest['version']!=version or manifest['build']!=build:raise SystemExit('Version mismatch')
    if a.feed.exists():
        old=ET.parse(a.feed)
        for v in old.findall('.//{'+NS+'}version'):
            if int(v.text)>=int(build):raise SystemExit('Release must increase the build number')
    rss=ET.Element('rss',version='2.0');channel=ET.SubElement(rss,'channel')
    ET.SubElement(channel,'title').text='Encore'
    item=ET.SubElement(channel,'item');ET.SubElement(item,'title').text=version
    for field,value in [('version',build),('shortVersionString',version),('minimumSystemVersion',info.get('LSMinimumSystemVersion','14.0'))]:ET.SubElement(item,'{'+NS+'}'+field).text=value
    url='https://github.com/conkamarian1987/ultimate-downloader-pro/releases/download/'+urllib.parse.quote(a.tag,safe='')+'/'+name
    ET.SubElement(item,'enclosure',{'url':url,'length':str(archive.stat().st_size),'type':'application/octet-stream','{'+NS+'}edSignature':manifest['signature']})
    a.feed.parent.mkdir(parents=True,exist_ok=True)
    ET.indent(rss);temp=a.feed.with_suffix('.tmp');ET.ElementTree(rss).write(temp,encoding='utf-8',xml_declaration=True);temp.replace(a.feed)
    print('Verified appcast:',a.feed)
if __name__=='__main__':main()
