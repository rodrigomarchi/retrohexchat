"""Bing Webmaster: payload normalisation, the throttled client, and the whole report.

The payloads are real ``GetUrlInfo``/``GetFeeds``/``GetUserSites`` answers for
retrohexchat.app; the API is never called.
"""

from __future__ import annotations

import json
import unittest
import urllib.parse
from datetime import datetime, timezone

from seo import bing
from seo.transport import FetchError

SITE = "https://retrohexchat.app/"
NOW = datetime(2026, 10, 7, 11, 20, 3, tzinfo=timezone.utc)
NEVER = "/Date(-62135596800000)/"

USER_SITES = [
    {"__type": "Site:#Microsoft.Bing.Webmaster.Api", "IsVerified": True, "Url": SITE},
    {"__type": "Site:#Microsoft.Bing.Webmaster.Api", "IsVerified": True, "Url": "https://other.example/"},
]
FEEDS = [
    {
        "Compressed": False,
        "FileSize": 1598,
        "LastCrawled": "/Date(1791225829000)/",
        "Status": "Success",
        "Submitted": "/Date(1791225829026)/",
        "Type": "Sitemap Index",
        "Url": "https://retrohexchat.app/sitemap.xml",
        "UrlCount": 8,
    }
]
URL_CRAWLED = {
    "AnchorCount": 0,
    "DiscoveryDate": "/Date(1770883200000)/",
    "DocumentSize": 102678,
    "HttpStatus": 0,
    "IsPage": True,
    "LastCrawledDate": "/Date(1780663302000)/",
    "Url": SITE,
}
URL_CRAWLED_EMPTY = {**URL_CRAWLED, "DocumentSize": 0, "Url": "https://retrohexchat.app/faq"}
URL_UNKNOWN = {**URL_CRAWLED, "DiscoveryDate": NEVER, "LastCrawledDate": NEVER, "DocumentSize": 0}
THROTTLED = json.dumps({"ErrorCode": 5, "Message": "ERROR!!! ThrottleHost"})


class FakeApi:
    """Answers ``Client`` requests by method name.

    An answer is the payload itself, or a function of the query parameters
    returning the payload or an exception to raise.
    """

    def __init__(self, answers: dict):
        self.answers = answers
        self.calls: list[tuple[str, dict]] = []

    def __call__(self, url: str) -> bytes:
        parsed = urllib.parse.urlsplit(url)
        method = parsed.path.rsplit("/", 1)[-1]
        params = dict(urllib.parse.parse_qsl(parsed.query))
        self.calls.append((method, params))
        answer = self.answers[method]
        if callable(answer):
            answer = answer(params)
        if isinstance(answer, Exception):
            raise answer
        return json.dumps({"d": answer}).encode()


def client(api: FakeApi, backoff=(1, 2)) -> tuple[bing.Client, list[float]]:
    slept: list[float] = []
    return bing.Client("SECRET-KEY", api, sleep=slept.append, backoff=backoff), slept


def answers(**overrides) -> dict:
    base = {
        "GetUserSites": USER_SITES,
        "GetFeeds": FEEDS,
        "GetCrawlIssues": [],
        "GetCrawlStats": [],
        "GetQueryStats": [],
        "GetPageStats": [],
        "GetUrlInfo": lambda params: URL_CRAWLED if params["url"] == SITE else URL_UNKNOWN,
        "GetUrlSubmissionQuota": {"DailyQuota": 100, "MonthlyQuota": 2500},
    }
    return {**base, **overrides}


class ParseDateTest(unittest.TestCase):
    def test_milliseconds_to_utc_iso(self):
        self.assertEqual(bing.parse_date("/Date(1791225829000)/"), "2026-10-05T18:43:49+00:00")

    def test_offset_suffix_is_accepted(self):
        self.assertEqual(bing.parse_date("/Date(1791225829000-0700)/"), "2026-10-05T18:43:49+00:00")

    def test_never_and_empty_are_none(self):
        for value in (NEVER, None, "", "not a date"):
            self.assertIsNone(bing.parse_date(value))


class IssueNamesTest(unittest.TestCase):
    def test_flags_decode_in_bit_order(self):
        self.assertEqual(bing.issue_names(4 | 1 | 256), ["redirect_301", "http_4xx", "timeout"])

    def test_none_and_unknown_bits(self):
        self.assertEqual(bing.issue_names(0), [])
        self.assertEqual(bing.issue_names(1024), ["unknown_1024"])


class UrlStateTest(unittest.TestCase):
    def test_states(self):
        self.assertEqual(bing.url_state(URL_CRAWLED), ("crawled", None))
        self.assertEqual(bing.url_state(URL_CRAWLED_EMPTY)[0], "crawled_empty")
        self.assertEqual(bing.url_state(URL_UNKNOWN)[0], "unknown")
        self.assertEqual(bing.url_state({**URL_UNKNOWN, "DiscoveryDate": "/Date(1770883200000)/"})[0], "discovered")
        self.assertEqual(bing.url_state({**URL_CRAWLED, "HttpStatus": 404}), ("error", "HTTP 404 on last fetch"))

    def test_normalized_row(self):
        self.assertEqual(
            bing.normalize_url_info(SITE, URL_CRAWLED),
            {
                "url": SITE,
                "state": "crawled",
                "discovered": "2026-02-12T08:00:00+00:00",
                "last_crawled": "2026-06-05T12:41:42+00:00",
                "detail": None,
            },
        )


class NormalizeTest(unittest.TestCase):
    def test_feeds(self):
        self.assertEqual(
            bing.normalize_feeds(FEEDS),
            [
                {
                    "url": "https://retrohexchat.app/sitemap.xml",
                    "type": "Sitemap Index",
                    "status": "Success",
                    "submitted": "2026-10-05T18:43:49+00:00",
                    "last_read": "2026-10-05T18:43:49+00:00",
                    "url_count": 8,
                    "errors": None,
                    "warnings": None,
                }
            ],
        )

    def test_crawl_issues(self):
        self.assertEqual(
            bing.normalize_crawl_issues([{"Url": "/gone", "Issues": 4, "HttpCode": 404, "InLinks": 2}]),
            [{"url": "/gone", "issues": ["http_4xx"], "http_status": 404}],
        )

    def test_crawl_stats_sorted_by_day_with_redirects_summed(self):
        rows = bing.normalize_crawl_stats(
            [
                {"Date": "/Date(1791225829000)/", "CrawledPages": 5, "Code301": 1, "Code302": 2, "InIndex": 9},
                {"Date": "/Date(1780663302000)/", "CrawledPages": 1},
            ]
        )
        self.assertEqual([r["date"] for r in rows], ["2026-06-05", "2026-10-05"])
        self.assertEqual(rows[1]["http_3xx"], 3)
        self.assertEqual(rows[1]["in_index"], 9)

    def test_performance_sums_weeks_and_weights_position_by_impressions(self):
        rows, period = bing.normalize_performance(
            [
                {"Query": "irc", "Clicks": 1, "Impressions": 10, "AvgImpressionPosition": 2.0, "Date": "/Date(1780663302000)/"},
                {"Query": "irc", "Clicks": 1, "Impressions": 30, "AvgImpressionPosition": 6.0, "Date": "/Date(1791225829000)/"},
                {"Query": "mirc", "Clicks": 0, "Impressions": 5, "AvgImpressionPosition": -1, "Date": "/Date(1791225829000)/"},
            ]
        )
        self.assertEqual(rows[0], {"key": "irc", "clicks": 2, "impressions": 40, "ctr": 0.05, "position": 5.0})
        self.assertIsNone(rows[1]["position"])
        self.assertEqual(period, {"start": "2026-06-05", "end": "2026-10-05"})
        self.assertEqual(bing.totals(rows)["impressions"], 45)

    def test_no_performance_rows(self):
        self.assertEqual(bing.normalize_performance([]), ([], None))


class ClientTest(unittest.TestCase):
    def test_unwraps_d_and_sends_key_and_params(self):
        api = FakeApi(answers())
        c, _ = client(api)
        self.assertEqual(c.call("GetFeeds", siteUrl=SITE), FEEDS)
        self.assertEqual(api.calls, [("GetFeeds", {"apikey": "SECRET-KEY", "siteUrl": SITE})])

    def test_throttling_waits_and_retries(self):
        attempts = iter([FetchError(400, THROTTLED), FetchError(400, THROTTLED), {"DailyQuota": 1}])

        def answer(_params):
            return next(attempts)

        c, slept = client(FakeApi(answers(GetUrlSubmissionQuota=answer)))
        self.assertEqual(c.call("GetUrlSubmissionQuota", siteUrl=SITE), {"DailyQuota": 1})
        self.assertEqual(slept, [1, 2])

    def test_throttling_past_the_backoff_raises_with_the_code(self):
        c, slept = client(FakeApi(answers(GetFeeds=lambda _p: FetchError(400, THROTTLED))))
        with self.assertRaises(bing.BingError) as caught:
            c.call("GetFeeds", siteUrl=SITE)
        self.assertEqual(caught.exception.code, bing.THROTTLE_CODE)
        self.assertEqual(slept, [1, 2])

    def test_an_html_error_page_is_transient_and_summarised_by_its_title(self):
        page = "<!DOCTYPE html><html><head><title>Service Unavailable</title></head><body>…</body></html>"
        attempts = iter([FetchError(503, page), FEEDS])
        c, slept = client(FakeApi(answers(GetFeeds=lambda _p: next(attempts))))
        self.assertEqual(c.call("GetFeeds", siteUrl=SITE), FEEDS)
        self.assertEqual(slept, [1])

        c, _ = client(FakeApi(answers(GetFeeds=lambda _p: FetchError(503, page))), backoff=())
        with self.assertRaises(bing.BingError) as caught:
            c.call("GetFeeds", siteUrl=SITE)
        self.assertEqual(str(caught.exception), "GetFeeds: HTTP 503, not JSON: Service Unavailable")

    def test_a_200_that_is_not_json_is_transient(self):
        calls = []

        def fetch(_url):
            calls.append(1)
            return b"<html><title>Oops</title></html>"

        c = bing.Client("SECRET-KEY", fetch, sleep=lambda _s: None, backoff=(1,))
        with self.assertRaisesRegex(bing.BingError, "HTTP 200, not JSON: Oops"):
            c.call("GetFeeds", siteUrl=SITE)
        self.assertEqual(len(calls), 2)

    def test_other_errors_fail_at_once_without_leaking_the_key(self):
        denied = FetchError(400, json.dumps({"ErrorCode": 14, "Message": "ERROR!!! NotAuthorized"}))
        c, slept = client(FakeApi(answers(GetFeeds=lambda _p: denied)))
        with self.assertRaises(bing.BingError) as caught:
            c.call("GetFeeds", siteUrl=SITE)
        self.assertEqual(str(caught.exception), "GetFeeds: HTTP 400, error 14: ERROR!!! NotAuthorized")
        self.assertNotIn("SECRET-KEY", str(caught.exception))
        self.assertEqual(slept, [])


class BuildReportTest(unittest.TestCase):
    def build(self, api: FakeApi, inspect=(SITE, "https://retrohexchat.app/nope")):
        c, _ = client(api)
        return bing.build_report(c, SITE, ["a", "b", "c"], list(inspect), NOW)

    def test_fills_every_section_and_derives_problems(self):
        report = self.build(FakeApi(answers()))
        self.assertEqual(report["source"], "bing")
        self.assertEqual(report["generated_at"], "2026-10-07T11:20:03+00:00")
        self.assertEqual(report["sitemaps"][0]["status"], "Success")
        self.assertEqual(report["crawl_issues"], [])
        self.assertEqual(report["inspection"]["sitemap_urls"], 3)
        self.assertEqual([r["state"] for r in report["inspection"]["urls"]], ["crawled", "unknown"])
        self.assertEqual(
            [p["kind"] for p in report["problems"]], ["inspection_unknown", "no_traffic", "stale_crawl"]
        )
        self.assertIn("URL submission quota left: 100 today, 2500 this month.", report["notes"])

    def test_a_site_outside_the_key_is_refused(self):
        api = FakeApi(answers(GetUserSites=[USER_SITES[1]]))
        with self.assertRaisesRegex(bing.BingError, "not a site of this API key"):
            self.build(api)

    def test_persistent_throttling_keeps_what_was_inspected(self):
        seen = []

        def url_info(params):
            seen.append(params["url"])
            return URL_CRAWLED if len(seen) == 1 else FetchError(400, THROTTLED)

        report = self.build(FakeApi(answers(GetUrlInfo=url_info)))
        self.assertEqual([r["url"] for r in report["inspection"]["urls"]], [SITE])
        self.assertTrue(any("Bing kept failing URL inspection: 1 of 2 URL(s) left uninspected" in n for n in report["notes"]))


if __name__ == "__main__":
    unittest.main()
