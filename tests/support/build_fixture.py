#!/usr/bin/env python3
# Builds a small release archive.json + manifest.json from a fixture
# source tree (fixture/src/) -- same shape maintainer/package-release.sh
# produces from the real content, just small enough to keep in a test.
# Signing happens separately (ssh-keygen -Y sign, called from the test
# script) since it needs the private key file, not this script.
import base64
import hashlib
import json
import os
import sys

fixture = sys.argv[1]
src = os.path.join(fixture, "src")

files = []
for root, _dirs, fnames in os.walk(src):
    for fn in fnames:
        full = os.path.join(root, fn)
        files.append(os.path.relpath(full, src))
files.sort()

filemap = {}
manifest_files = {}
for rel in files:
    with open(os.path.join(src, rel), "rb") as fh:
        data = fh.read()
    filemap[rel] = base64.b64encode(data).decode()
    manifest_files[rel] = hashlib.sha256(data).hexdigest()

manifest = {"version": "9.9.9", "files": manifest_files}
manifest_json = json.dumps(manifest, sort_keys=True, separators=(",", ":"))
archive_json = json.dumps(filemap)

with open(os.path.join(fixture, "manifest.json"), "w") as fh:
    fh.write(manifest_json)
with open(os.path.join(fixture, "archive.json"), "w") as fh:
    fh.write(archive_json)
