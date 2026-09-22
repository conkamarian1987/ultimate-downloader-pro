import socket,http.server,functools,pathlib
socket.getfqdn=lambda name:name
root=pathlib.Path(__file__).resolve().parents[1]
http.server.ThreadingHTTPServer(('127.0.0.1',18766),functools.partial(http.server.SimpleHTTPRequestHandler,directory=str(root/'test-media'))).serve_forever()
