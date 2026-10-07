"""The only network and environment access the SEO readers make.

Sources take a ``fetch`` callable instead of calling these directly, so tests
hand them canned responses and never touch the network.
"""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from pathlib import Path
from typing import Callable

USER_AGENT = "retro-hex-chat-seo-console/1"
TIMEOUT_SECONDS = 30

Fetch = Callable[[str], bytes]


class FetchError(RuntimeError):
    """An HTTP failure, carrying the status and the response body."""

    def __init__(self, status: int, body: str):
        super().__init__(f"HTTP {status}: {body[:500]}")
        self.status = status
        self.body = body


def fetch(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json, */*"})
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            return response.read()
    except urllib.error.HTTPError as error:
        raise FetchError(error.code, error.read().decode("utf-8", "replace")) from None


Post = Callable[[str, dict], tuple[int, str]]


def post_json(url: str, payload: dict) -> tuple[int, str]:
    """``(status, body)`` for any answer, error statuses included: the caller decides what they mean."""
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode(),
        method="POST",
        headers={"User-Agent": USER_AGENT, "Content-Type": "application/json; charset=utf-8"},
    )
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            return response.status, response.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode("utf-8", "replace")


def fetch_json(fetcher: Fetch, url: str):
    return json.loads(fetcher(url))


def parse_dotenv(text: str) -> dict[str, str]:
    """``KEY=value`` lines; blank lines, comments and ``export`` prefixes allowed, quotes stripped."""
    values: dict[str, str] = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.removeprefix("export ").partition("=")
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        values[key.strip()] = value
    return values


def env_value(name: str, dotenv: Path) -> str | None:
    """The process environment wins over the ``.env`` file."""
    if os.environ.get(name):
        return os.environ[name]
    if dotenv.is_file():
        return parse_dotenv(dotenv.read_text()).get(name) or None
    return None
