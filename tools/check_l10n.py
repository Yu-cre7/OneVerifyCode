#!/usr/bin/env python3
"""Validate that every OVCStr key has an English translation and matching format specifiers."""
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
STRINGS = ROOT / "assets/en.lproj/Localizable.strings"
SOURCE_GLOB = "src/*.m"
KEY_RE = re.compile(r'OVCStr\(@"([^"\\]*)"\)')
PLACEHOLDER_RE = re.compile(r'%(?:@|ld|lu|lld|d|\.0f|\.1f|%)')

raw = subprocess.check_output(["plutil", "-convert", "json", "-o", "-", str(STRINGS)])
translations = json.loads(raw)
keys = set()
for path in sorted(ROOT.glob(SOURCE_GLOB)):
    keys.update(KEY_RE.findall(path.read_text(encoding="utf-8")))

missing = sorted(k for k in keys if k not in translations)
bad_format = []
for key in sorted(keys & translations.keys()):
    source_tokens = PLACEHOLDER_RE.findall(key)
    target_tokens = PLACEHOLDER_RE.findall(translations[key])
    if source_tokens != target_tokens:
        bad_format.append((key, source_tokens, target_tokens))

if missing:
    print("Missing translations:")
    for key in missing:
        print(f"  {key}")
if bad_format:
    print("Format mismatch:")
    for key, source_tokens, target_tokens in bad_format:
        print(f"  {key}: {source_tokens} != {target_tokens}")
if missing or bad_format:
    sys.exit(1)
print(f"l10n: {len(keys)} keys, {len(translations)} translations, 0 missing, 0 format mismatch")
