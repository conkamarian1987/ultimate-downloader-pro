import http.server,threading,subprocess,pathlib,functools
root=pathlib.Path(__file__).resolve().parents[1]
handler=functools.partial(http.server.SimpleHTTPRequestHandler,directory=str(root/'test-media'))
import socket
socket.getfqdn=lambda name: name
server=http.server.ThreadingHTTPServer(('127.0.0.1',18765),handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
 with (root/'test-results.log').open('w') as log:
  result=subprocess.run([str(root/'smoke-tests'),str(root/'test-output-hls'),'http://127.0.0.1:18765/master.m3u8'],stdout=log,stderr=subprocess.STDOUT,timeout=240)
 print('Smoke test exit:',result.returncode)
 print('\n'.join(x for x in (root/'test-results.log').read_text().splitlines() if 'PASS' in x or 'ERROR' in x or 'Fatal' in x))
 raise SystemExit(result.returncode)
finally:server.shutdown()
