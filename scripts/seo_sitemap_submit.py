#!/usr/bin/env python3
"""Ask Google to read the sitemap again.

    make seo.sitemap.submit

Google takes no IndexNow, and reads the sitemap on its own schedule; this
tells it now. ``make deploy`` runs it once production is confirmed to serve
the new release. It runs only where the service account is configured — the
machine that deploys, never the server:

    GOOGLE_SERVICE_ACCOUNT_FILE   path to the service account's JSON key (in
                                  the environment or the repository's .env)

The last line is always ``sitemap: submitted|skipped|failed — …``, which is
what the deploy reads. Skipped exits 0; failed exits 1.

Stdlib only, like every gate.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from seo import google
from seo.transport import env_value, request

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SITE = "https://retrohexchat.app/"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--site", default=DEFAULT_SITE)
    parser.add_argument("--env-file", type=Path, default=ROOT / ".env")
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)

    path = env_value("GOOGLE_SERVICE_ACCOUNT_FILE", args.env_file)
    if not path:
        print("sitemap: skipped — GOOGLE_SERVICE_ACCOUNT_FILE is not set")
        return 0

    sitemap_url = f"{args.site}sitemap.xml"
    try:
        account = json.loads(Path(path).expanduser().read_text())
        token = google.ServiceAccountToken(account, request, scope=google.WRITE_SCOPE)
        client = google.Client(token, request)
        prop = google.resolve_property(client, args.site)
        google.submit_sitemap(client, prop, sitemap_url)
    except (OSError, ValueError, google.GoogleError) as error:
        print(f"sitemap: failed — {error}")
        return 1

    print(f"sitemap: submitted — {sitemap_url} to {prop}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
