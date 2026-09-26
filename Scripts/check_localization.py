#!/usr/bin/env python3
"""Fails when a user-facing string in the app is missing from any translation.

Collects every L("…") / LF("…") key and every App Intents title/description/parameter title,
and checks every App/Resources/<language>.lproj/Localizable.strings: all keys present and the same
format placeholders as the English text.
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STRINGS = os.path.join(ROOT, "App", "Resources", "zh-Hans.lproj", "Localizable.strings")
LITERAL = r'"((?:[^"\\]|\\.)*)"'


def swift_unescape(text):
    text = re.sub(r"\\u\{([0-9A-Fa-f]+)\}", lambda m: chr(int(m.group(1), 16)), text)
    return text.replace('\\"', '"').replace("\\\\", "\\")


def code_keys():
    keys = set()
    for path in glob.glob(os.path.join(ROOT, "App", "Sources", "**", "*.swift"), recursive=True):
        source = open(path, encoding="utf-8").read()
        keys.update(re.findall(r"\bLF?\(\s*" + LITERAL, source))
        # LF(condition ? "a" : "b", …) and `format = "…"` variables passed to LF.
        for a, b in re.findall(r"LF\([^\"\n]*\?\s*" + LITERAL + r"\s*:\s*" + LITERAL, source):
            keys.update([a, b])
        keys.update(re.findall(r"format = " + LITERAL, source))
        keys.update(re.findall(r'NSLocalizedString\(\s*' + LITERAL, source))
        if "/Intents/" in path:
            keys.update(re.findall(r"(?:title: LocalizedStringResource = |IntentDescription\(|@Parameter\(title: |"
                                   r"TypeDisplayRepresentation = |\.\w+: )" + LITERAL, source))
    return {swift_unescape(k) for k in keys}


SPECIFIER = re.compile(r"%(?:\d+\$)?l{0,2}[@dufs]")


def parse_strings(path):
    text = open(path, encoding="utf-8").read()
    pairs = re.findall(r'^' + LITERAL + r'\s*=\s*' + LITERAL + r'\s*;', text, flags=re.M)
    return {swift_unescape(k): swift_unescape(v) for k, v in pairs}


def translated_keys(language="zh-Hans"):
    return set(parse_strings(os.path.join(ROOT, "App", "Resources", f"{language}.lproj", "Localizable.strings")))


def languages():
    folders = glob.glob(os.path.join(ROOT, "App", "Resources", "*.lproj"))
    return sorted(os.path.basename(f)[:-6] for f in folders if not f.endswith("en.lproj"))


def main():
    keys = code_keys()
    failed = False
    for language in languages():
        table = parse_strings(os.path.join(ROOT, "App", "Resources", f"{language}.lproj", "Localizable.strings"))
        missing = sorted(keys - set(table))
        stale = sorted(set(table) - keys)
        wrong = sorted(k for k in keys & set(table)
                       if sorted(SPECIFIER.findall(k)) != sorted(SPECIFIER.findall(table[k])))
        if missing:
            failed = True
            print(f"[{language}] missing translations:")
            for key in missing:
                print(f'  "{key}"')
        if wrong:
            failed = True
            print(f"[{language}] placeholders (%@, %ld, …) differ from the English text:")
            for key in wrong:
                print(f'  "{key}"  ->  "{table[key]}"')
        if stale:
            print(f"[{language}] warning: {len(stale)} unused entries (safe to delete):")
            for key in stale:
                print(f'  "{key}"')
    if failed:
        return 1
    print(f"Localization OK: {len(keys)} strings in {len(languages())} languages ({', '.join(languages())}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
