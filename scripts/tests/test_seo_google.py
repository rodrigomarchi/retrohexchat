"""Google Search Console: the token, the client, the normalisers and the whole report.

The payloads follow the shapes in the API reference; the API is never called.
The signature test runs the real ``openssl`` against a key generated for it.
"""

from __future__ import annotations

import base64
import json
import shutil
import subprocess
import tempfile
import unittest
import urllib.parse
from datetime import date, datetime, timezone
from pathlib import Path

from seo import google

SITE = "https://retrohexchat.app/"
PROP = "sc-domain:retrohexchat.app"
NOW = datetime(2026, 10, 7, 12, 0, 0, tzinfo=timezone.utc)
ACCOUNT = {
    "client_email": "seo-reader@project.iam.gserviceaccount.com",
    "private_key": "-----BEGIN PRIVATE KEY-----\nSECRET\n-----END PRIVATE KEY-----\n",
    "token_uri": "https://oauth2.googleapis.com/token",
}

SITES = {
    "siteEntry": [
        {"siteUrl": "https://other.example/", "permissionLevel": "siteOwner"},
        {"siteUrl": PROP, "permissionLevel": "siteFullUser"},
    ]
}
SITEMAPS = {
    "sitemap": [
        {
            "path": "https://retrohexchat.app/sitemap.xml",
            "lastSubmitted": "2026-10-05T18:43:49.000Z",
            "isPending": False,
            "isSitemapsIndex": True,
            "lastDownloaded": "2026-10-06T02:10:00.000Z",
            "warnings": "2",
            "errors": "0",
            "contents": [{"type": "web", "submitted": "5469", "indexed": "0"}],
        }
    ]
}
INDEXED = {
    "inspectionResult": {
        "indexStatusResult": {
            "verdict": "PASS",
            "coverageState": "Submitted and indexed",
            "robotsTxtState": "ALLOWED",
            "indexingState": "INDEXING_ALLOWED",
            "lastCrawlTime": "2026-09-30T08:12:44Z",
            "pageFetchState": "SUCCESSFUL",
            "googleCanonical": "https://retrohexchat.app/",
            "userCanonical": "https://retrohexchat.app/",
        }
    }
}
DUPLICATE = {
    "inspectionResult": {
        "indexStatusResult": {
            "verdict": "NEUTRAL",
            "coverageState": "Duplicate, Google chose different canonical than user",
            "robotsTxtState": "ALLOWED",
            "indexingState": "INDEXING_ALLOWED",
            "lastCrawlTime": "2026-09-12T10:00:00Z",
            "pageFetchState": "SUCCESSFUL",
            "googleCanonical": "https://retrohexchat.app/faq",
            "userCanonical": "https://retrohexchat.app/pt-BR/faq",
        }
    }
}
UNKNOWN = {"inspectionResult": {"indexStatusResult": {"verdict": "NEUTRAL", "coverageState": "URL is unknown to Google"}}}
QUERIES = {
    "rows": [
        {"keys": ["mirc online"], "clicks": 3, "impressions": 140, "ctr": 0.021, "position": 11.2},
        {"keys": ["irc chat"], "clicks": 9, "impressions": 90, "ctr": 0.1, "position": 4.0},
    ]
}
TOTALS = {"rows": [{"clicks": 12, "impressions": 230, "ctr": 0.052, "position": 8.4}]}


class FakeRequest:
    """Answers by URL and body; records every call."""

    def __init__(self, routes):
        self.routes = routes
        self.calls = []

    def __call__(self, method, url, body, headers):
        self.calls.append((method, url, body, headers))
        decoded = json.loads(body) if body and headers.get("Content-Type", "").startswith("application/json") else None
        for match, answer in self.routes:
            if match(method, url, decoded):
                status, payload = answer(decoded) if callable(answer) else answer
                return status, json.dumps(payload).encode()
        raise AssertionError(f"unexpected call {method} {url} {decoded}")


def routes(inspect=lambda body: (200, INDEXED if body["inspectionUrl"] == SITE else UNKNOWN)):
    base = f"{google.WEBMASTERS}/sites/{urllib.parse.quote(PROP, safe='')}"
    return [
        (lambda m, u, b: u == f"{google.WEBMASTERS}/sites", (200, SITES)),
        (lambda m, u, b: u == f"{base}/sitemaps", (200, SITEMAPS)),
        (lambda m, u, b: u.endswith("/searchAnalytics/query") and "dimensions" not in b, (200, TOTALS)),
        (lambda m, u, b: u.endswith("/searchAnalytics/query") and b["dimensions"] == ["query"], (200, QUERIES)),
        (lambda m, u, b: u.endswith("/searchAnalytics/query") and b["dimensions"] == ["page"], (200, {})),
        (lambda m, u, b: u == google.INSPECT, inspect),
    ]


def client(fake, backoff=(1, 2)):
    slept = []
    return google.Client(lambda: "ACCESS-TOKEN", fake, sleep=slept.append, backoff=backoff), slept


class TokenTest(unittest.TestCase):
    def _decode(self, part):
        return json.loads(base64.urlsafe_b64decode(part + "=" * (-len(part) % 4)))

    def test_the_assertion_names_the_account_scope_and_audience(self):
        signed = []
        assertion = google.jwt_assertion(ACCOUNT, 1_000, lambda key, data: signed.append((key, data)) or b"sig")
        header, claims, signature = assertion.split(".")

        self.assertEqual(self._decode(header), {"alg": "RS256", "typ": "JWT"})
        self.assertEqual(
            self._decode(claims),
            {"iss": ACCOUNT["client_email"], "scope": google.SCOPE, "aud": ACCOUNT["token_uri"], "iat": 1_000, "exp": 4_600},
        )
        self.assertEqual(signature, base64.urlsafe_b64encode(b"sig").rstrip(b"=").decode())
        self.assertEqual(signed[0][1], f"{header}.{claims}".encode())

    def test_fetched_once_and_reused_until_it_nearly_expires(self):
        clock = [1_000.0]
        fake = FakeRequest([(lambda m, u, b: True, (200, {"access_token": "T1", "expires_in": 3600}))])
        token = google.ServiceAccountToken(ACCOUNT, fake, sign=lambda k, d: b"s", clock=lambda: clock[0])

        self.assertEqual(token(), "T1")
        clock[0] += 3000
        self.assertEqual(token(), "T1")
        self.assertEqual(len(fake.calls), 1)
        clock[0] += 600
        token()
        self.assertEqual(len(fake.calls), 2)

    def test_a_refused_token_names_the_reason_not_the_key(self):
        fake = FakeRequest([(lambda m, u, b: True, (400, {"error": "invalid_grant", "error_description": "Invalid JWT"}))])
        token = google.ServiceAccountToken(ACCOUNT, fake, sign=lambda k, d: b"s")
        with self.assertRaises(google.GoogleError) as caught:
            token()
        self.assertEqual(str(caught.exception), "token: HTTP 400, invalid_grant Invalid JWT")
        self.assertNotIn("SECRET", str(caught.exception))

    def test_an_incomplete_account_file_is_refused(self):
        with self.assertRaisesRegex(google.GoogleError, "no private_key"):
            google.ServiceAccountToken({**ACCOUNT, "private_key": ""}, FakeRequest([]))


@unittest.skipUnless(shutil.which("openssl"), "openssl is not installed")
class OpensslSignTest(unittest.TestCase):
    def test_signs_with_rs256_that_the_public_key_verifies(self):
        work = Path(tempfile.mkdtemp())
        key, pub, data, sig = work / "k.pem", work / "p.pem", work / "d", work / "s"
        subprocess.run(["openssl", "genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:2048", "-out", str(key)], check=True, capture_output=True)
        subprocess.run(["openssl", "pkey", "-in", str(key), "-pubout", "-out", str(pub)], check=True, capture_output=True)
        data.write_bytes(b"header.claims")

        sig.write_bytes(google.openssl_sign(key.read_text(), b"header.claims"))

        verified = subprocess.run(
            ["openssl", "dgst", "-sha256", "-verify", str(pub), "-signature", str(sig), str(data)], capture_output=True
        )
        self.assertEqual(verified.returncode, 0, verified.stdout + verified.stderr)

    def test_a_bad_key_is_an_error_not_a_crash(self):
        with self.assertRaisesRegex(google.GoogleError, "openssl could not sign"):
            google.openssl_sign("not a key", b"data")


class ClientTest(unittest.TestCase):
    def test_sends_the_bearer_token_and_json(self):
        fake = FakeRequest([(lambda m, u, b: True, (200, {"ok": True}))])
        c, _ = client(fake)
        self.assertEqual(c.post("https://api.example/x", {"a": 1}), {"ok": True})
        method, _url, body, headers = fake.calls[0]
        self.assertEqual((method, json.loads(body), headers["Authorization"]), ("POST", {"a": 1}, "Bearer ACCESS-TOKEN"))

    def test_throttling_and_server_errors_retry(self):
        answers = iter([(429, {"error": {"status": "RESOURCE_EXHAUSTED"}}), (503, {}), (200, {"ok": 1})])
        c, slept = client(FakeRequest([(lambda m, u, b: True, lambda _b: next(answers))]))
        self.assertEqual(c.get("https://api.example/x"), {"ok": 1})
        self.assertEqual(slept, [1, 2])

    def test_a_refusal_fails_at_once_with_googles_words(self):
        denied = (403, {"error": {"status": "PERMISSION_DENIED", "message": "User does not have sufficient permission"}})
        c, slept = client(FakeRequest([(lambda m, u, b: True, denied)]))
        with self.assertRaises(google.GoogleError) as caught:
            c.get(f"{google.WEBMASTERS}/sites/x/sitemaps")
        self.assertEqual(str(caught.exception), "sitemaps: HTTP 403, PERMISSION_DENIED User does not have sufficient permission")
        self.assertEqual(slept, [])


class NormaliseTest(unittest.TestCase):
    def test_the_domain_property_wins_over_the_url_prefix(self):
        sites = [{"siteUrl": SITE, "permissionLevel": "siteOwner"}, {"siteUrl": PROP, "permissionLevel": "siteOwner"}]
        self.assertEqual(google.property_for(sites, SITE), PROP)
        self.assertEqual(google.property_for(sites[:1], SITE), SITE)

    def test_an_unverified_property_is_not_readable(self):
        self.assertIsNone(google.property_for([{"siteUrl": PROP, "permissionLevel": "siteUnverifiedUser"}], SITE))

    def test_sitemaps(self):
        self.assertEqual(
            google.normalize_sitemaps(SITEMAPS["sitemap"]),
            [
                {
                    "url": "https://retrohexchat.app/sitemap.xml",
                    "type": "Sitemap Index",
                    "status": "Success",
                    "submitted": "2026-10-05T18:43:49+00:00",
                    "last_read": "2026-10-06T02:10:00+00:00",
                    "url_count": 5469,
                    "errors": 0,
                    "warnings": 2,
                }
            ],
        )

    def test_inspection_states(self):
        def state(**result):
            return google.inspection_state(result)

        self.assertEqual(state(verdict="PASS", coverageState="Submitted and indexed"), ("indexed", None))
        self.assertEqual(state(verdict="NEUTRAL", coverageState="URL is unknown to Google")[0], "unknown")
        self.assertEqual(state(verdict="NEUTRAL", coverageState="Discovered - currently not indexed")[0], "discovered")
        self.assertEqual(state(verdict="NEUTRAL", coverageState="Crawled - currently not indexed")[0], "not_indexed")
        self.assertEqual(
            state(verdict="FAIL", coverageState="Soft 404", pageFetchState="SOFT_404"), ("error", "Soft 404 (soft_404)")
        )

    def test_a_noindex_or_robots_block_is_named(self):
        self.assertEqual(google.blocked_by({"indexingState": "BLOCKED_BY_META_TAG"}), "noindex")
        self.assertEqual(google.blocked_by({"robotsTxtState": "DISALLOWED"}), "robots_txt")
        self.assertIsNone(google.blocked_by({"indexingState": "INDEXING_ALLOWED", "robotsTxtState": "ALLOWED"}))

    def test_an_inspected_row_carries_both_canonicals(self):
        row = google.normalize_inspection("https://retrohexchat.app/pt-BR/faq", DUPLICATE)
        self.assertEqual(row["state"], "not_indexed")
        self.assertEqual(row["canonical_declared"], "https://retrohexchat.app/pt-BR/faq")
        self.assertEqual(row["canonical_chosen"], "https://retrohexchat.app/faq")
        self.assertEqual(row["last_crawled"], "2026-09-12T10:00:00+00:00")

    def test_rows_and_window(self):
        rows = google.normalize_rows(QUERIES)
        self.assertEqual([r["key"] for r in rows], ["irc chat", "mirc online"])
        self.assertEqual(rows[1]["position"], 11.2)
        self.assertEqual(google.performance_window(date(2026, 10, 7)), (date(2026, 9, 7), date(2026, 10, 4)))


class BuildReportTest(unittest.TestCase):
    def build(self, fake, vitals=None):
        c, _ = client(fake)
        return google.build_report(c, SITE, ["a", "b"], [SITE, "https://retrohexchat.app/nope"], NOW, web_vitals=vitals)

    def test_fills_every_section_google_has_and_derives_problems(self):
        report = self.build(FakeRequest(routes()), vitals=lambda pages: [])

        self.assertEqual(report["source"], "google")
        self.assertIsNone(report["crawl_issues"])
        self.assertIsNone(report["crawl_stats"])
        self.assertEqual(report["sitemaps"][0]["warnings"], 2)
        self.assertEqual(report["performance"]["totals"]["clicks"], 12)
        self.assertEqual(report["period"], {"start": "2026-09-07", "end": "2026-10-04"})
        self.assertEqual([r["state"] for r in report["inspection"]["urls"]], ["indexed", "unknown"])
        self.assertEqual(report["web_vitals"], [])
        kinds = [p["kind"] for p in report["problems"]]
        self.assertEqual(kinds, ["inspection_unknown", "sitemap_warnings", "striking_distance"])
        self.assertIn(f"Search Console property: {PROP}.", report["notes"])

    def test_inspection_uses_the_property_not_the_url(self):
        fake = FakeRequest(routes())
        self.build(fake)
        inspected = [json.loads(b) for m, u, b, h in fake.calls if u == google.INSPECT]
        self.assertTrue(all(b["siteUrl"] == PROP for b in inspected))

    def test_a_site_the_account_cannot_read_is_refused(self):
        fake = FakeRequest([(lambda m, u, b: True, (200, {"siteEntry": [SITES["siteEntry"][0]]}))])
        with self.assertRaisesRegex(google.GoogleError, "not a property this service account can read"):
            self.build(fake)

    def test_the_inspection_quota_keeps_what_was_inspected(self):
        def inspect(body):
            if body["inspectionUrl"] == SITE:
                return 200, INDEXED
            return 429, {"error": {"status": "RESOURCE_EXHAUSTED"}}

        c, _ = client(FakeRequest(routes(inspect)), backoff=())
        report = google.build_report(c, SITE, ["a"], [SITE, "https://retrohexchat.app/x"], NOW)
        self.assertEqual(len(report["inspection"]["urls"]), 1)
        self.assertTrue(any("1 of 2 URL(s) left uninspected" in n for n in report["notes"]))


if __name__ == "__main__":
    unittest.main()
