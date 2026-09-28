#!/usr/bin/env python3
"""Exercise the production YouTube URL parser without a WebKit session."""
from pathlib import Path
import subprocess
import tempfile
source = (Path(__file__).resolve().parents[1] / "Sources/PageScanner.swift").read_text()
start = source.index("    static func videoID(")
end = source.index("\n}\n\nprivate struct Embedded", start)
code = "import Foundation\nenum YouTubePlayer {\n" + source[start:end] + "\n}\n"
code += '\nlet valid = [\n "https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=abc",\n "https://youtu.be/dQw4w9WgXcQ?t=12",\n "https://www.youtube.com/shorts/dQw4w9WgXcQ",\n "https://www.youtube.com/live/dQw4w9WgXcQ",\n "https://www.youtube.com/embed/dQw4w9WgXcQ",\n "https://music.youtube.com/watch?v=dQw4w9WgXcQ"\n]\nfor url in valid { precondition(YouTubePlayer.videoID(URL(string:url)!) == "dQw4w9WgXcQ", url) }\nfor url in ["https://youtube.com/playlist?list=abc", "https://evil.youtube.com/watch?v=dQw4w9WgXcQ", "https://youtube.com/watch?v=bad", "https://example.com/dQw4w9WgXcQ", "https://youtu.be/dQw4w9WgXc!"] {\n precondition(YouTubePlayer.videoID(URL(string:url)!) == nil, url)\n}\nprint("PASS: 11 YouTube URL cases")\n'
with tempfile.TemporaryDirectory(prefix="youtube-url-tests-") as tmp:
    root = Path(tmp)
    (root / "tests.swift").write_text(code)
    subprocess.run(["swiftc", "-module-cache-path", str(root / "cache"), str(root / "tests.swift"), "-o", str(root / "tests")], check=True)
    subprocess.run([str(root / "tests")], check=True)
