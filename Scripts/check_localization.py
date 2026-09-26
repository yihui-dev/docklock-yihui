#!/usr/bin/env python3
"""Fails when a user-facing string in the app has no Simplified Chinese translation.

Collects every L("…") / LF("…") key and every App Intents title/description/parameter title,
and compares them with App/Resources/zh-Hans.lproj/Localizable.strings.
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


def translated_keys():
    text = open(STRINGS, encoding="utf-8").read()
    return {swift_unescape(k) for k in re.findall(r'^' + LITERAL + r'\s*=', text, flags=re.M)}


def main():
    missing = sorted(code_keys() - translated_keys())
    if missing:
        print("Missing zh-Hans translations:")
        for key in missing:
            print(f'  "{key}"')
        return 1
    print(f"Localization OK ({len(code_keys())} strings).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
