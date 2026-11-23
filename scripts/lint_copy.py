#!/usr/bin/env python3
"""Banned-terms check for user-facing copy (PLAN.md §15.1 — App Review guideline 1.4.1).

Scans Swift string literals and String Catalogs (.xcstrings) for diagnostic/medical-claim wording.

Usage:
  python3 -I scripts/lint_copy.py [--report] <path> [<path> ...]

Exits 1 when violations are found, unless --report is given (used until the Phase 2 copy rewrite lands).
"""
import json
import re
import sys
from pathlib import Path

BANNED = [
    r"\bdiagnos(e|es|ed|is|tic)\b",
    r"\btreat(s|ed|ing|ment|ments)?\b",
    r"\bcur(e|es|ed|ing)\b",
    r"\bdisease\b",
    r"\bprescri(be|ption)\b",
    r"\bclinically proven\b",
    r"\bmedical(ly)?\b",
    r"\bsevere\b",
]
# Phrases that legitimately contain a banned word (e.g. disclaimers).
ALLOWED_CONTEXT = [
    r"not a medical",
    r"isn't a medical",
    r"is not a medical",
    r"medical device",
    r"not a substitute for professional medical",
    r"not medical advice",
    r"^https?://",  # cited sources, not copy
]
STRING_LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
PATTERNS = [re.compile(p, re.IGNORECASE) for p in BANNED]
ALLOWED = [re.compile(p, re.IGNORECASE) for p in ALLOWED_CONTEXT]


def violations_in(text: str) -> list[str]:
    if any(a.search(text) for a in ALLOWED):
        return []
    return [m.group(0) for p in PATTERNS for m in p.finditer(text)]


def scan_swift(path: Path) -> list[tuple[str, int, str, list[str]]]:
    found = []
    for number, line in enumerate(path.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("//") or "Logger" in line or "logger." in line:
            continue
        for literal in STRING_LITERAL.findall(line):
            hits = violations_in(literal)
            if hits:
                found.append((str(path), number, literal[:90], hits))
    return found


def scan_catalog(path: Path) -> list[tuple[str, int, str, list[str]]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    found = []
    for key, entry in data.get("strings", {}).items():
        texts = [key] + [
            unit.get("stringUnit", {}).get("value", "")
            for unit in entry.get("localizations", {}).values()
        ]
        for text in texts:
            hits = violations_in(text)
            if hits:
                found.append((str(path), 0, text[:90], hits))
    return found


def scan_lessons(path: Path) -> list[tuple[str, int, str, list[str]]]:
    """Skin School lessons (SkinSchool.json): every English and Indonesian string."""
    found = []

    def walk(value):
        if isinstance(value, dict):
            for key, inner in value.items():
                if key != "url":
                    walk(inner)
        elif isinstance(value, list):
            for inner in value:
                walk(inner)
        elif isinstance(value, str):
            hits = violations_in(value)
            if hits:
                found.append((str(path), 0, value[:90], hits))

    walk(json.loads(path.read_text(encoding="utf-8")))
    return found


def main(argv: list[str]) -> int:
    report_only = "--report" in argv
    roots = [Path(a) for a in argv if a != "--report"] or [Path(".")]
    results = []
    for root in roots:
        for path in root.rglob("*.swift"):
            # Tests list the banned words on purpose (to assert they never ship); they are not user-facing copy.
            if any(part.endswith("Tests") or part == ".build" for part in path.parts):
                continue
            results += scan_swift(path)
        for path in root.rglob("*.xcstrings"):
            results += scan_catalog(path)
        for path in root.rglob("SkinSchool.json"):
            if ".build" not in path.parts:
                results += scan_lessons(path)
    for file, line, text, hits in results:
        print(f"{file}:{line}: {sorted(set(h.lower() for h in hits))}  \"{text}\"")
    print(f"{len(results)} copy violation(s)")
    return 0 if report_only or not results else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
