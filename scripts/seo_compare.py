#!/usr/bin/env python3
"""Prove a change to the public pages took nothing away from what is indexed.

    make seo.snapshot BASE=http://localhost:4003 OUT=tmp/seo/before   # old code
    make seo.snapshot BASE=http://localhost:4004 OUT=tmp/seo/after    # new code
    make seo.compare BEFORE=tmp/seo/before AFTER=tmp/seo/after

    make seo.snapshot.all BASE=... OUT=...   # every URL the sitemap lists

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
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ElementTree
from html.parser import HTMLParser
from pathlib import Path

SITEMAP_NS = "{http://www.sitemaps.org/schemas/sitemap/0.9}"

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
    "/games",
    "/pt-BR/games/doom-shareware",
    "/mirc-commands",
    "/pt-BR/mirc-online",
    "/irc-chat",
]

CLOCK = re.compile(r"\d{1,2}:\d{2}")


def _is_chrome(attrs: dict) -> bool:
    """The desktop's own furniture, around the page rather than in it: the Start
    menu, the taskbar and its menus, the desktop's icons, folders and dialogs,
    the clock, and the sign-in form — the same on every page, and since the one
    desktop a window of its own at /connect. Which of it ships in the first
    response is a performance decision, not a change to what a page says, so
    its words are not the page's text."""
    window_id = attrs.get("data-window-id") or ""
    classes = (attrs.get("class") or "").split()

    return (
        "data-window-start-menu" in attrs
        or "data-taskbar-menu" in attrs
        or "data-window-shortcut" in attrs
        or "data-clock" in attrs
        or window_id.startswith("desktop-launcher-")
        or "data-desktop-connect-dialog" in attrs
        or attrs.get("data-testid") == "landing-connect-window"
        or "desktop-taskbar" in classes
        or "desktop-shortcut" in classes
    )


class _Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.seo: list[tuple] = []
        self.text: list[str] = []
        self._skip = 0
        self._chrome: tuple[str, int] | None = None
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

        if self._chrome and tag == self._chrome[0]:
            self._chrome = (tag, self._chrome[1] + 1)
        elif not self._chrome and _is_chrome(attrs):
            self._chrome = (tag, 1)

    def handle_startendtag(self, tag, attrs):
        # A self-closed tag opens nothing: never count it as entering chrome.
        chrome = self._chrome
        self.handle_starttag(tag, attrs)
        self._chrome = chrome

    def handle_endtag(self, tag):
        if self._chrome and tag == self._chrome[0]:
            depth = self._chrome[1] - 1
            self._chrome = (tag, depth) if depth else None

        if self._in and tag == ("script" if self._in == "ld+json" else self._in):
            self.seo.append((self._in, " ".join(self._buffer.split())))
            self._in = None

        if tag in ("script", "style"):
            self._skip -= 1

    def handle_data(self, data):
        if self._in:
            self._buffer += data

        if not self._skip and not self._chrome and data.strip():
            self.text.append(" ".join(data.split()))


def parse(html: str) -> _Page:
    page = _Page()
    page.feed(html)
    return page


def file_name(path: str) -> str:
    name = path.strip("/").replace("/", "__").replace("?", "__q__").replace("&", "__")
    return (name or "index") + ".html"


def sitemap_paths(base: str, fetch=None) -> list[str]:
    """Every page path the sitemap at `base` lists, following its child sitemaps.

    The sitemap names pages on the public origin, which a local build shares
    only by configuration, so each URL is reduced to its path and query and
    fetched again from `base`. A child sitemap is reached the same way.
    """
    fetch = fetch or _fetch
    paths: list[str] = []
    pending = ["/sitemap.xml"]

    while pending:
        root = ElementTree.fromstring(fetch(base.rstrip("/") + pending.pop(0)))

        for loc in root.iter(f"{SITEMAP_NS}loc"):
            path = _path_of(loc.text or "")

            if root.tag == f"{SITEMAP_NS}sitemapindex":
                pending.append(path)
            elif path not in paths:
                paths.append(path)

    return paths


def _path_of(url: str) -> str:
    parts = urllib.parse.urlsplit(url.strip())
    return (parts.path or "/") + (f"?{parts.query}" if parts.query else "")


FETCH_TIMEOUT = 30
RETRIES = 4


def _fetch(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=FETCH_TIMEOUT) as response:
        return response.read()


def _transient(error: Exception) -> bool:
    """A timeout, a dropped connection or a 5xx is worth asking again; a 4xx is an answer."""
    if isinstance(error, urllib.error.HTTPError):
        return error.code >= 500
    return isinstance(error, (urllib.error.URLError, TimeoutError, ConnectionError))


def _fetch_patiently(url: str, fetch, sleep) -> bytes:
    for attempt in range(RETRIES):
        try:
            return fetch(url)
        except Exception as error:  # noqa: BLE001 — re-raised unless transient
            if not _transient(error) or attempt == RETRIES - 1:
                raise
            print(f"retry {url}: {error}", file=sys.stderr)
            sleep(2**attempt)
    raise AssertionError("unreachable")


def snapshot(base: str, out: Path, paths: list[str], *, resume: bool = False, fetch=_fetch, sleep=time.sleep) -> int:
    """Save every path. A sweep of thousands of URLs meets a timeout sooner or
    later, so a transient failure is retried with backoff, and `resume` skips the
    pages an interrupted sweep already saved."""
    out.mkdir(parents=True, exist_ok=True)
    skipped = 0

    for path in paths:
        target = out / file_name(path)

        if resume and target.exists() and target.stat().st_size > 0:
            skipped += 1
            continue

        target.write_bytes(_fetch_patiently(base.rstrip("/") + path, fetch, sleep))

    print(f"{len(paths) - skipped} pages saved to {out}" + (f" ({skipped} already there)" if skipped else ""))
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
    snap.add_argument(
        "--from-sitemap",
        action="store_true",
        help="snapshot every page the sitemap at BASE lists instead of the default set",
    )
    snap.add_argument(
        "--resume",
        action="store_true",
        help="keep the pages OUT already holds and fetch only the rest",
    )
    snap.add_argument("paths", nargs="*", default=DEFAULT_PATHS)

    comp = sub.add_parser("compare")
    comp.add_argument("before", type=Path)
    comp.add_argument("after", type=Path)

    args = parser.parse_args()

    if args.command == "snapshot":
        paths = sitemap_paths(args.base) if args.from_sitemap else args.paths
        return snapshot(args.base, args.out, paths, resume=args.resume)

    return compare(args.before, args.after)


if __name__ == "__main__":
    sys.exit(main())
