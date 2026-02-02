#!/usr/bin/env python3
"""
Minimal mrhttp HTTP server for benchmark comparison
Install: pip install mrhttp
Run: python server.py
Serves on port 3006
"""

from mrhttp import Application, Response
import re

app = Application()

# Embed files at startup (like Orisha's compile-time embedding)
with open("public/index.html", "r") as f:
    INDEX_HTML = f.read()
with open("public/about.html", "r") as f:
    ABOUT_HTML = f.read()

# Pre-compute bytes for zero-copy serving
INDEX_BYTES = INDEX_HTML.encode("utf-8")
ABOUT_BYTES = ABOUT_HTML.encode("utf-8")
HEALTH_BYTES = b'{"status":"ok"}'

# Regex for user ID extraction
USER_PATTERN = re.compile(r"^/api/users/([^/]+)$")


@app.route("/")
async def index(request):
    return Response(body=INDEX_BYTES, content_type="text/html; charset=utf-8")


@app.route("/about")
async def about(request):
    return Response(body=ABOUT_BYTES, content_type="text/html; charset=utf-8")


@app.route("/api/health")
async def health(request):
    return Response(body=HEALTH_BYTES, content_type="application/json")


@app.route("/api/users/{id}")
async def get_user(request, id):
    body = f'{{"id":"{id}","name":"User {id}"}}'.encode("utf-8")
    return Response(body=body, content_type="application/json")


if __name__ == "__main__":
    print("mrhttp server listening on :3006")
    app.run(host="127.0.0.1", port=3006)
