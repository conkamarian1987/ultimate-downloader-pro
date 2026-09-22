import subprocess,pathlib,concurrent.futures,json
root=pathlib.Path(__file__).resolve().parents[1]/'ProviderTests'
cases={
 'instagram-gallery':['/opt/homebrew/bin/gallery-dl','--config-ignore','--dump-json','--range','1-5','--retries','0','--http-timeout','10','--','https://www.instagram.com/p/BQ0eAlwhDrw/'],
 'tiktok-video':['/opt/homebrew/bin/yt-dlp','--ignore-config','--dump-single-json','--skip-download','--socket-timeout','10','--retries','0','--extractor-retries','0','--','https://www.tiktok.com/@patroxofficial/video/6742501081818877190'],
}
def check(pair):
 name,args=pair
 with (root/(name+'.json')).open('w') as out,(root/(name+'.log')).open('w') as err:
  try:r=subprocess.run(args,stdout=out,stderr=err,timeout=40);return {'name':name,'exit':r.returncode}
  except subprocess.TimeoutExpired:return {'name':name,'timeout':True}
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(check,cases.items()))
(root/'provider-results.json').write_text(json.dumps(results,indent=2));print(results)
