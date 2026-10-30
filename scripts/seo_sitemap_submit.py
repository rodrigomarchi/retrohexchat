#!/usr/bin/env python3
"""Ask Google and Bing to read the sitemap again.

    make seo.sitemap.submit

Both read a sitemap on their own schedule; this tells them now. ``make deploy``
runs it once production is confirmed to serve the new release. It runs only
where the credentials are configured — the machine that deploys, never the
server. An engine with no credential is left out, and the other is still asked:

    GOOGLE_SERVICE_ACCOUNT_FILE   path to the service account's JSON key (in
                                  the environment or the repository's .env)
    BING_WEBMASTER_API_KEY        Bing Webmaster's API key, likewise

The last line is always ``sitemap: submitted|skipped|failed — …``, which is
what the deploy reads. Skipped exits 0; failed exits 1.

Stdlib only, like every gate.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from seo import bing, google
from seo.transport import env_value, post_json, request

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SITE = "https://retrohexchat.app/"


def submit_google(args: argparse.Namespace, sitemap_url: str) -> str | None:
    path = env_value("GOOGLE_SERVICE_ACCOUNT_FILE", args.env_file)
    if not path:
        return None
    account = json.loads(Path(path).expanduser().read_text())
    token = google.ServiceAccountToken(account, request, scope=google.WRITE_SCOPE)
    client = google.Client(token, request)
    prop = google.resolve_property(client, args.site)
    google.submit_sitemap(client, prop, sitemap_url)
    return prop


def submit_bing(args: argparse.Namespace, sitemap_url: str) -> str | None:
    key = env_value("BING_WEBMASTER_API_KEY", args.env_file)
    if not key:
        return None
    bing.submit_sitemap(post_json, key, args.site, sitemap_url)
    return "Bing"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--site", default=DEFAULT_SITE)
    parser.add_argument("--env-file", type=Path, default=ROOT / ".env")
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)

    sitemap_url = f"{args.site}sitemap.xml"
    submitted: list[str] = []
    failures: list[str] = []
    for name, submit in (("Google", submit_google), ("Bing", submit_bing)):
        try:
            target = submit(args, sitemap_url)
        except (OSError, ValueError, google.GoogleError, bing.BingError) as error:
            failures.append(f"{name}: {error}")
            continue
        if target:
            submitted.append(target)

    if failures:
        print(f"sitemap: failed — {'; '.join(failures)}")
        return 1
    if not submitted:
        print("sitemap: skipped — neither GOOGLE_SERVICE_ACCOUNT_FILE nor BING_WEBMASTER_API_KEY is set")
        return 0
    print(f"sitemap: submitted — {sitemap_url} to {', '.join(submitted)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
