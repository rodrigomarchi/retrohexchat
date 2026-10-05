#!/usr/bin/env python3
"""Prove a change to the public pages took nothing away from what is indexed.

    make seo.snapshot BASE=http://localhost:4003 OUT=tmp/seo/before   # old code
    make seo.snapshot BASE=http://localhost:4004 OUT=tmp/seo/after    # new code
    make seo.compare BEFORE=tmp/seo/before AFTER=tmp/seo/after

A raw HTML diff of two builds is unreadable: CSRF and LiveView session tokens
change on every request and HEEx does not promise attribute order. What a
search engine ranks is narrower, so that is what is compared: the title, the
description and robots metas, the canonical, hreflang and prev/next links, the
Open Graph and Twitter tags, the JSON-LD, the h1 — which must be identical —
and the visible text, of which nothing may be lost. Text may be added; a page
that gained a link is fine, a page that lost a paragraph fails.

Stdlib only, like every gate.
"""

from __future__ import annotations

import argparse
import re
import sys
import urllib.request
from html.parser import HTMLParser
from pathlib import Path

# Pages that already rank or are crawled most: the landing in English and two
# other locales, and the help pages search engines visit. Extend it when a page starts to matter.
DEFAULT_PATHS = [
    "/",
    "/how-it-works",
    "/features",
    "/privacy",
    "/install",
    "/community",
    "/faq",
    "/pt-BR",
    "/pt-BR/features",
    "/ja/faq",
    "/chat/help",
    "/chat/help/feature-arcade-doom-shareware",
    "/pt-BR/chat/help/feature-arcade-quake-shareware",
]

CLOCK = re.compile(r"\d{1,2}:\d{2}")


class _Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.seo: list[tuple] = []
        self.text: list[str] = []
        self._skip = 0
        self._in = None
        self._buffer = ""

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        name = attrs.get("name") or attrs.get("property") or ""

        if tag == "meta" and (name in ("description", "robots") or name.startswith(("og:", "twitter:"))):
            self.seo.append(("meta", name, attrs.get("content")))
        elif tag == "link" and attrs.get("rel") in ("canonical", "alternate", "prev", "next"):
            self.seo.append(("link", attrs.get("rel"), attrs.get("hreflang"), attrs.get("href")))
        elif tag in ("title", "h1"):
            self._in, self._buffer = tag, ""
        elif tag == "script" and attrs.get("type") == "application/ld+json":
            self._in, self._buffer = "ld+json", ""

        if tag in ("script", "style"):
            self._skip += 1

    def handle_endtag(self, tag):
        if self._in and tag == ("script" if self._in == "ld+json" else self._in):
            self.seo.append((self._in, " ".join(self._buffer.split())))
            self._in = None

        if tag in ("script", "style"):
            self._skip -= 1

    def handle_data(self, data):
        if self._in:
            self._buffer += data

        if not self._skip and data.strip():
            self.text.append(" ".join(data.split()))


def parse(html: str) -> _Page:
    page = _Page()
    page.feed(html)
    return page


def file_name(path: str) -> str:
    return (path.strip("/").replace("/", "__") or "index") + ".html"


def snapshot(base: str, out: Path, paths: list[str]) -> int:
    out.mkdir(parents=True, exist_ok=True)

    for path in paths:
        with urllib.request.urlopen(base.rstrip("/") + path) as response:
            (out / file_name(path)).write_bytes(response.read())

    print(f"{len(paths)} pages saved to {out}")
    return 0


def compare(before: Path, after: Path) -> int:
    failures = 0
    pages = sorted(before.glob("*.html"))

    # A mistyped BEFORE globs to nothing, and comparing nothing proves nothing.
    if not pages:
        print(f"FAIL no snapshot pages in {before}")
        return 1

    for old_file in pages:
        new_file = after / old_file.name

        if not new_file.exists():
            print(f"FAIL {old_file.name}: missing from {after}")
            failures += 1
            continue

        old, new = parse(old_file.read_text("utf-8")), parse(new_file.read_text("utf-8"))
        changed_seo = sorted(set(map(repr, old.seo)) ^ set(map(repr, new.seo)))
        new_text = set(new.text)
        lost = sorted(t for t in set(old.text) if t not in new_text and not CLOCK.fullmatch(t))
        added = sorted(t for t in new_text - set(old.text) if not CLOCK.fullmatch(t))

        if changed_seo or lost:
            failures += 1
            print(f"FAIL {old_file.name}")

            for item in changed_seo[:10]:
                print(f"     seo changed: {item[:160]}")

            for item in lost[:10]:
                print(f"     text lost:   {item[:160]}")
        else:
            print(f"ok   {old_file.name}" + (f"  (+ {'; '.join(added)[:120]})" if added else ""))

    return 1 if failures else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    snap = sub.add_parser("snapshot")
    snap.add_argument("--base", required=True)
    snap.add_argument("--out", required=True, type=Path)
    snap.add_argument("paths", nargs="*", default=DEFAULT_PATHS)

    comp = sub.add_parser("compare")
    comp.add_argument("before", type=Path)
    comp.add_argument("after", type=Path)

    args = parser.parse_args()

    if args.command == "snapshot":
        return snapshot(args.base, args.out, args.paths)

    return compare(args.before, args.after)


if __name__ == "__main__":
    sys.exit(main())
