#!/usr/bin/env python3
"""Read a search engine's webmaster console into one standard report.

    make seo.console SOURCE=bing                     # reports/seo/<UTC stamp>-bing.{json,md}
    make seo.console SOURCE=bing INSPECT=100
    make seo.console SOURCE=google
    python3 scripts/seo_console.py bing --url https://retrohexchat.app/faq

Every source fills the same shape (``scripts/seo/report.py``), so reports from
different engines and different days read and diff the same way. Each run
writes new files named by its UTC generation time; nothing is overwritten.

Credentials come from the environment or the repository's ``.env``:
    bing    BING_WEBMASTER_API_KEY
    google  GOOGLE_SERVICE_ACCOUNT_FILE   path to the service account's JSON key,
                                          kept outside the repository
            CRUX_API_KEY                  optional: Web Vitals from real visitors

Stdlib only, like every gate.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path

from seo import bing, crux, google, sitemap
from seo import report as rpt
from seo.transport import FetchError, env_value, fetch, post_json, request

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SITE = "https://retrohexchat.app/"
DEFAULT_OUT = ROOT / "reports" / "seo"
DEFAULT_INSPECT = 40


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", choices=["bing", "google"])
    parser.add_argument("--site", default=DEFAULT_SITE, help="property URL, with the trailing slash")
    parser.add_argument("--sitemap", help="sitemap to sample from (default: <site>sitemap.xml)")
    parser.add_argument("--inspect", type=int, default=DEFAULT_INSPECT, help="sitemap URLs to inspect, spread evenly")
    parser.add_argument("--url", action="append", default=[], help="always inspect this URL (repeatable)")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--env-file", type=Path, default=ROOT / ".env")
    return parser.parse_args(argv)


def run_bing(args: argparse.Namespace, now: datetime) -> dict:
    key = env_value("BING_WEBMASTER_API_KEY", args.env_file)
    if not key:
        raise SystemExit(f"BING_WEBMASTER_API_KEY is not set (environment or {args.env_file}).")
    urls, inspect = _sample(args)
    return bing.build_report(bing.Client(key, fetch), args.site, urls, inspect, now, progress=_progress)


def run_google(args: argparse.Namespace, now: datetime) -> dict:
    path = env_value("GOOGLE_SERVICE_ACCOUNT_FILE", args.env_file)
    if not path:
        raise SystemExit(f"GOOGLE_SERVICE_ACCOUNT_FILE is not set (environment or {args.env_file}).")
    account_file = Path(path).expanduser()
    if account_file.resolve().is_relative_to(ROOT):
        raise SystemExit(f"{account_file} is inside the repository; keep the service account key outside it.")
    account = json.loads(account_file.read_text())
    client = google.Client(google.ServiceAccountToken(account, request), request)

    vitals = None
    crux_key = env_value("CRUX_API_KEY", args.env_file)
    if crux_key:
        parts = urllib.parse.urlsplit(args.site)
        origin = f"{parts.scheme}://{parts.netloc}"

        def vitals(pages: list[dict]) -> list[dict]:
            return crux.collect(post_json, crux_key, origin, pages)

    urls, inspect = _sample(args)
    report = google.build_report(client, args.site, urls, inspect, now, web_vitals=vitals, progress=_progress)
    if not crux_key:
        report["notes"].append("Web Vitals skipped: CRUX_API_KEY is not set.")
    return report


def _sample(args: argparse.Namespace) -> tuple[list[str], list[str]]:
    urls = sitemap.collect(fetch, args.sitemap or f"{args.site}sitemap.xml")
    return urls, sitemap.sample(urls, args.inspect, always=[args.site, *args.url])


def _progress(message: str) -> None:
    print(f"  {message}", file=sys.stderr)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    print(f"Reading {args.source} for {args.site}", file=sys.stderr)
    try:
        run = run_google if args.source == "google" else run_bing
        report = run(args, datetime.now(timezone.utc))
    except (bing.BingError, google.GoogleError, crux.CruxError, FetchError) as error:
        print(f"{args.source}: {error}", file=sys.stderr)
        return 1
    json_path, md_path = rpt.write(report, args.out)
    for problem in report["problems"]:
        print(f"{problem['severity']:>7}  {problem['kind']}: {problem['message']}")
    if not report["problems"]:
        print("No problems found.")
    print(f"\n{md_path.relative_to(ROOT) if md_path.is_relative_to(ROOT) else md_path}")
    print(f"{json_path.relative_to(ROOT) if json_path.is_relative_to(ROOT) else json_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
