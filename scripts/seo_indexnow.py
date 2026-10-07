#!/usr/bin/env python3
"""Announce the site's public URLs to IndexNow (Bing, Yandex, Seznam, Naver).

    make seo.indexnow                         # every URL in the sitemap
    make seo.indexnow ARGS=--dry-run          # what would be sent, nothing sent
    python3 scripts/seo_indexnow.py --url https://retrohexchat.app/pt-BR/faq

The server already announces what each release changed and each new archive
day. Run this after a change that moves no page's date — a shared component, a
translation — so the engines refetch everything.

Stdlib only, like every gate.
"""

from __future__ import annotations

import argparse
import sys

from seo import indexnow, sitemap
from seo.transport import FetchError, fetch, post_json

DEFAULT_SITE = "https://retrohexchat.app/"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--site", default=DEFAULT_SITE)
    parser.add_argument("--url", action="append", default=[], help="announce only these URLs (repeatable)")
    parser.add_argument("--dry-run", action="store_true", help="build the requests, send nothing")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        key = indexnow.read_key(fetch, args.site)
        urls = args.url or sitemap.collect(fetch, f"{args.site}sitemap.xml")
        bodies = indexnow.payloads(urls, key)
    except (indexnow.IndexNowError, FetchError) as error:
        print(f"indexnow: {error}", file=sys.stderr)
        return 1

    total = sum(len(b["urlList"]) for b in bodies)
    print(f"{total} URL(s) in {len(bodies)} request(s) for {args.site}")
    if args.dry_run:
        return 0

    failed = False
    for count, status, body in indexnow.submit(bodies, post_json):
        ok = status in indexnow.ACCEPTED
        failed |= not ok
        print(f"  {count:>6} URL(s): HTTP {status}" + ("" if ok else f" — {body}"))
        if "SiteVerificationNotCompleted" in body:
            print("  The engine has not fetched the key yet (it was published recently); run this again later.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
