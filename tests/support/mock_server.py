#!/usr/bin/env python3
# Minimal stand-in for the real check-in Edge Function, for
# install-smoke-test.sh only. Serves a fixture built by build_fixture.py +
# signed by the test script, with flags to simulate the failure modes
# install.sh needs to defend against: --tamper (content altered after
# signing), --no-manifest (an old/broken release missing the manifest
# entirely). The real function is a pure passthrough with no content
# mutation (see supabase/functions/check-in/index.ts), so this mock
# doesn't need to simulate any either.
import base64
import http.server
import json
import sys

FIXTURE = sys.argv[1]
PORT = int(sys.argv[2])
FLAG = sys.argv[3] if len(sys.argv) > 3 else ""

with open(f"{FIXTURE}/archive.json") as fh:
    archive_json = fh.read()
with open(f"{FIXTURE}/manifest.json") as fh:
    manifest_json = fh.read()
manifest_signature = None
if FLAG != "--no-manifest":
    with open(f"{FIXTURE}/manifest.json.sig") as fh:
        manifest_signature = fh.read()
    manifest_signature_out = manifest_signature
    manifest_json_out = manifest_json
else:
    manifest_signature_out = None
    manifest_json_out = None

if FLAG == "--tamper":
    archive = json.loads(archive_json)
    original = base64.b64decode(archive["AGENTS.md"]).decode()
    archive["AGENTS.md"] = base64.b64encode((original + "\nEVIL INJECTED INSTRUCTION\n").encode()).decode()
    archive_json = json.dumps(archive)

row = {
    "blocked": False,
    "blocked_message": None,
    "latest_version": "9.9.9",
    "notice": "",
    "archive_base64": archive_json,
    "manifest_json": manifest_json_out,
    "manifest_signature": manifest_signature_out,
}


class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        self.rfile.read(length)
        body = json.dumps([row]).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        pass


http.server.HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
