#!/usr/bin/env python3
"""
ATON Server - Airgap Package Download Server
포트 31889에서 airgap_package.tar.gz 파일을 다운로드할 수 있는 웹서버
"""

import http.server
import socketserver
import os
import sys
from string import Template
from datetime import datetime

PORT = 31889
PACKAGE_DIR = os.environ.get("PACKAGE_DIR", ".")
PACKAGE_FILENAME = "airgap_package.tar.gz"
PACKAGE_FILE = os.path.join(PACKAGE_DIR, PACKAGE_FILENAME)

HTML_TEMPLATE = Template("""<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ATON Server - Airgap Package Download</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            color: #fff;
        }
        .container {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 40px;
            text-align: center;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            max-width: 500px;
            width: 90%;
        }
        h1 {
            font-size: 1.8rem;
            margin-bottom: 10px;
            color: #4fc3f7;
        }
        .subtitle {
            color: #aaa;
            margin-bottom: 30px;
            font-size: 0.9rem;
        }
        .file-info {
            background: rgba(0, 0, 0, 0.2);
            border-radius: 10px;
            padding: 20px;
            margin-bottom: 25px;
        }
        .file-name {
            font-family: monospace;
            font-size: 1.1rem;
            color: #81c784;
            margin-bottom: 10px;
        }
        .file-size {
            color: #aaa;
            font-size: 0.9rem;
        }
        .file-date {
            color: #aaa;
            font-size: 0.85rem;
            margin-top: 8px;
        }
        .download-btn {
            display: inline-block;
            background: linear-gradient(135deg, #4fc3f7 0%, #29b6f6 100%);
            color: #000;
            text-decoration: none;
            padding: 15px 40px;
            border-radius: 30px;
            font-weight: bold;
            font-size: 1.1rem;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .download-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 20px rgba(79, 195, 247, 0.4);
        }
        .download-btn.disabled {
            background: #666;
            color: #999;
            cursor: not-allowed;
        }
        .download-btn.disabled:hover {
            transform: none;
            box-shadow: none;
        }
        .instructions {
            margin-top: 30px;
            text-align: left;
            font-size: 0.85rem;
            color: #aaa;
        }
        .instructions h3 {
            color: #fff;
            margin-bottom: 10px;
            font-size: 1rem;
        }
        .instructions code {
            background: rgba(0, 0, 0, 0.3);
            padding: 2px 6px;
            border-radius: 4px;
            font-family: monospace;
            color: #81c784;
        }
        .instructions ol {
            margin-left: 20px;
            line-height: 1.8;
        }
        .error {
            color: #ef5350;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>ATON Server</h1>
        <p class="subtitle">Airgap Package Download</p>

        <div class="file-info">
            <div class="file-name">$filename</div>
            <div class="file-size">$filesize</div>
            <div class="file-date">$filedate</div>
        </div>

        $download_section

        <div class="instructions">
            <h3>설치 방법</h3>
            <ol>
                <li>파일 다운로드 후 폐쇄망 환경으로 전송</li>
                <li>압축 해제: <code>tar xzf $filename</code></li>
                <li>설치 실행: <code>cd airgap_package && sudo ./install_airgap.sh</code></li>
            </ol>
        </div>
    </div>
</body>
</html>
""")

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            self.send_index_page()
        elif self.path == f"/{PACKAGE_FILENAME}":
            self.send_file()
        else:
            self.send_error(404, "Not Found")

    def send_index_page(self):
        if os.path.exists(PACKAGE_FILE):
            size = os.path.getsize(PACKAGE_FILE)
            if size >= 1024 * 1024 * 1024:
                size_str = f"{size / (1024 * 1024 * 1024):.2f} GB"
            elif size >= 1024 * 1024:
                size_str = f"{size / (1024 * 1024):.2f} MB"
            elif size >= 1024:
                size_str = f"{size / 1024:.2f} KB"
            else:
                size_str = f"{size} bytes"

            # 파일 수정 시간 가져오기
            mtime = os.path.getmtime(PACKAGE_FILE)
            date_str = datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M:%S")

            download_section = f'<a href="/{PACKAGE_FILENAME}" class="download-btn">다운로드</a>'
        else:
            size_str = "파일 없음"
            date_str = "-"
            download_section = '''
                <span class="download-btn disabled">파일 없음</span>
                <p class="error">airgap_package.tar.gz 파일이 없습니다.<br>
                먼저 <code>sudo ./export_for_airgap.sh</code>를 실행하세요.</p>
            '''

        html = HTML_TEMPLATE.substitute(
            filename=PACKAGE_FILENAME,
            filesize=size_str,
            filedate=f"업데이트: {date_str}",
            download_section=download_section
        )

        self.send_response(200)
        self.send_header("Content-type", "text/html; charset=utf-8")
        self.send_header("Content-Length", len(html.encode()))
        self.end_headers()
        self.wfile.write(html.encode())

    def send_file(self):
        if not os.path.exists(PACKAGE_FILE):
            self.send_error(404, "File not found")
            return

        file_size = os.path.getsize(PACKAGE_FILE)

        self.send_response(200)
        self.send_header("Content-Type", "application/gzip")
        self.send_header("Content-Disposition", f'attachment; filename="{PACKAGE_FILENAME}"')
        self.send_header("Content-Length", file_size)
        self.end_headers()

        with open(PACKAGE_FILE, "rb") as f:
            while chunk := f.read(8192):
                self.wfile.write(chunk)

    def log_message(self, format, *args):
        print(f"[{self.log_date_time_string()}] {args[0]}")


def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)) or ".")

    with socketserver.TCPServer(("", PORT), CustomHandler) as httpd:
        print(f"=" * 50)
        print(f"  ATON Server - Airgap Package Download Server")
        print(f"=" * 50)
        print(f"  URL: http://0.0.0.0:{PORT}")
        print(f"  파일: {PACKAGE_FILE}")
        if os.path.exists(PACKAGE_FILE):
            size_mb = os.path.getsize(PACKAGE_FILE) / (1024 * 1024)
            print(f"  크기: {size_mb:.2f} MB")
        else:
            print(f"  상태: 파일 없음 (export_for_airgap.sh 실행 필요)")
        print(f"=" * 50)
        print(f"  종료하려면 Ctrl+C를 누르세요")
        print()

        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n서버 종료")
            sys.exit(0)


if __name__ == "__main__":
    main()
