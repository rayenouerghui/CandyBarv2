#!/usr/bin/env python3
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(__file__), '..')
UI_DIR = os.path.normpath(os.path.join(ROOT, 'ui'))
PATTERNS = [
    r'FastBlur',
    r'ShaderEffectSource',
    r'ShaderEffect',
    r'GraphicalEffects',
    r'OpacityMask',
    r'Glow',
    r'DropShadow'
]
regex = re.compile('|'.join('(?:%s)' % p for p in PATTERNS))

found = []
for dirpath, dirnames, filenames in os.walk(UI_DIR):
    for fn in filenames:
        if not fn.endswith('.qml'):
            continue
        path = os.path.join(dirpath, fn)
        try:
            with open(path, 'r', encoding='utf-8') as f:
                for i, line in enumerate(f, start=1):
                    if regex.search(line):
                        found.append((path, i, line.rstrip('\n')))
        except Exception as e:
            print(f"[lint] Failed to read {path}: {e}", file=sys.stderr)

if found:
    print('[lint] Lightweight UI check failed — heavy effects found:')
    for p, ln, text in found:
        rel = os.path.relpath(p, ROOT)
        print(f'{rel}:{ln}: {text}')
    sys.exit(2)

print('[lint] Lightweight UI check passed — no heavy effects found.')
sys.exit(0)
