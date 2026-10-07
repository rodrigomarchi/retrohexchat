"""IndexNow, sent by hand: the same request the server's job sends, for a whole sitemap.

The server announces what a release changed and each new archive day on its
own (``RetroHexChat.Jobs.IndexNowWorker``). This covers what it cannot see: a
change to a component shared by every page moves no page's date, so after one
the whole site is announced from here.

The key is read from the site itself (``/indexnow.txt``), the same file the
engines verify against, so it is never copied anywhere.
"""

from __future__ import annotations

import re
import urllib.parse

from seo.transport import Fetch, Post

API = "https://api.indexnow.org/indexnow"
KEY_PATH = "/indexnow.txt"
BATCH_SIZE = 10_000
ACCEPTED = (200, 202)

# The protocol's key: 8 to 128 characters of letters, digits and dashes.
_KEY = re.compile(r"[A-Za-z0-9-]{8,128}")


class IndexNowError(RuntimeError):
    pass


def read_key(fetcher: Fetch, site: str) -> str:
    key = fetcher(urllib.parse.urljoin(site, KEY_PATH)).decode("utf-8", "replace").strip()
    if not _KEY.fullmatch(key):
        raise IndexNowError(f"{site.rstrip('/')}{KEY_PATH} does not hold an IndexNow key")
    return key


def payloads(urls: list[str], key: str) -> list[dict]:
    """One request body per batch of at most ten thousand URLs, all on one host."""
    urls = list(dict.fromkeys(urls))
    if not urls:
        return []
    origins = {(p.scheme, p.netloc) for p in map(urllib.parse.urlsplit, urls)}
    if len(origins) != 1:
        raise IndexNowError(f"URLs span {len(origins)} hosts; IndexNow takes one per request")
    scheme, host = origins.pop()
    return [
        {
            "host": host,
            "key": key,
            "keyLocation": f"{scheme}://{host}{KEY_PATH}",
            "urlList": urls[i : i + BATCH_SIZE],
        }
        for i in range(0, len(urls), BATCH_SIZE)
    ]


def submit(bodies: list[dict], post: Post) -> list[tuple[int, int, str]]:
    """``(url count, status, body)`` per request; stops at the first refusal."""
    results = []
    for body in bodies:
        status, text = post(API, body)
        results.append((len(body["urlList"]), status, text[:300]))
        if status not in ACCEPTED:
            break
    return results
