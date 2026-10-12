#!/usr/bin/env python3
"""Verify complete snapshot checksums and current packaged Godot payloads."""
from pathlib import Path
from html.parser import HTMLParser
import gzip
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]

def verify():
    rows = (ROOT / 'MANIFEST.sha256').read_text(encoding='utf8').splitlines()
    seen = set()
    for row in rows:
        digest, name = row.split('  ', 1)
        path = ROOT / name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise SystemExit('Checksum failed: ' + name)
        seen.add(name)
    actual = {p.relative_to(ROOT).as_posix() for p in ROOT.rglob('*') if p.is_file()
              and p.name != 'MANIFEST.sha256' and '__pycache__' not in p.parts}
    if actual != seen:
        raise SystemExit('Manifest does not match package files')
    metadata = json.loads((ROOT / 'VERSION.json').read_text(encoding='utf8'))
    project = (ROOT / 'game-source/project.godot').read_text(encoding='utf8')
    if 'config/version="' + metadata['version'] + '"' not in project:
        raise SystemExit('Godot source version mismatch')
    web = ROOT / 'game-source/docs/play'
    html = (web / 'index.html').read_text(encoding='utf8')
    if 'v' + metadata['version'] not in html or 'build ' + metadata['build'] not in html:
        raise SystemExit('Web build version mismatch')
    packed = json.loads(re.search(r'const PACKED = (\{.*?\});', html).group(1))
    for kind, (names, size, mime) in packed.items():
        names = [names] if isinstance(names, str) else names
        blob = b''.join((web / name).read_bytes() for name in names)
        if len(blob) != size:
            raise SystemExit('Packed size mismatch: ' + kind)
        raw = gzip.decompress(blob)
        if hashlib.sha1(raw).hexdigest()[:8] not in names[0]:
            raise SystemExit('Packed content mismatch: ' + kind)
    class References(HTMLParser):
        def __init__(self, directory):
            super().__init__()
            self.directory = directory
        def handle_starttag(self, tag, attrs):
            for key, value in attrs:
                if key not in ('src', 'href') or not value or value.startswith(('http', '#', 'data:')):
                    continue
                plain = value.split('?')[0].split('#')[0]
                dest = web / plain.lstrip('/') if plain.startswith('/') else self.directory / plain
                if not dest.exists():
                    raise SystemExit('Missing page reference: ' + value)
    for page in [web / 'index.html', web / 'divine-sanctum/index.html', web / 'star-expansion/index.html']:
        References(page.parent).feed(page.read_text(encoding='utf8'))
    print('PASS:', len(rows), 'files, source v' + metadata['version'], 'build', metadata['build'], 'payloads and page references')

if __name__ == '__main__':
    verify()
