"""Chrome UX Report: field data rated by the shared thresholds, and 404 read as "too little traffic"."""

from __future__ import annotations

import json
import unittest

from seo import crux

RECORD = {
    "record": {
        "key": {"formFactor": "PHONE", "origin": "https://retrohexchat.app"},
        "metrics": {
            "largest_contentful_paint": {"histogram": [], "percentiles": {"p75": 3100}},
            "interaction_to_next_paint": {"histogram": [], "percentiles": {"p75": 140}},
            "cumulative_layout_shift": {"histogram": [], "percentiles": {"p75": "0.31"}},
        },
        "collectionPeriod": {
            "firstDate": {"year": 2026, "month": 9, "day": 7},
            "lastDate": {"year": 2026, "month": 10, "day": 4},
        },
    }
}


class NormalizeTest(unittest.TestCase):
    def test_p75_rated_and_cls_read_as_a_number(self):
        vital = crux.normalize(RECORD["record"], "origin")
        self.assertEqual(vital["target"], "https://retrohexchat.app")
        self.assertEqual(vital["period"], "2026-09-07 → 2026-10-04")
        self.assertEqual(
            vital["metrics"],
            {
                "largest_contentful_paint": {"p75": 3100, "rating": "needs_improvement"},
                "interaction_to_next_paint": {"p75": 140, "rating": "good"},
                "cumulative_layout_shift": {"p75": 0.31, "rating": "poor"},
            },
        )


class QueryTest(unittest.TestCase):
    def test_asks_for_the_origin_or_the_page_by_device(self):
        sent = []

        def post(url, body):
            sent.append((url, body))
            return 200, json.dumps(RECORD)

        crux.query(post, "API-KEY", "https://retrohexchat.app", "origin", "PHONE")
        crux.query(post, "API-KEY", "https://retrohexchat.app/faq", "page", "DESKTOP")

        self.assertTrue(sent[0][0].endswith("?key=API-KEY"))
        self.assertEqual(sent[0][1]["origin"], "https://retrohexchat.app")
        self.assertEqual(sent[1][1]["url"], "https://retrohexchat.app/faq")
        self.assertEqual(sent[1][1]["formFactor"], "DESKTOP")

    def test_too_little_traffic_is_no_record(self):
        self.assertIsNone(crux.query(lambda u, b: (404, "{}"), "K", "https://x.app", "origin", "PHONE"))

    def test_any_other_failure_is_raised(self):
        with self.assertRaisesRegex(crux.CruxError, "HTTP 403"):
            crux.query(lambda u, b: (403, "API key not valid"), "K", "https://x.app", "origin", "PHONE")


class CollectTest(unittest.TestCase):
    def test_origin_then_the_top_pages_keeping_only_those_with_data(self):
        asked = []

        def post(url, body):
            asked.append((body.get("origin") or body.get("url"), body["formFactor"]))
            return (200, json.dumps(RECORD)) if "origin" in body else (404, "{}")

        found = crux.collect(post, "K", "https://retrohexchat.app", [{"key": "https://retrohexchat.app/faq"}])
        self.assertEqual(
            asked,
            [
                ("https://retrohexchat.app", "PHONE"),
                ("https://retrohexchat.app", "DESKTOP"),
                ("https://retrohexchat.app/faq", "PHONE"),
                ("https://retrohexchat.app/faq", "DESKTOP"),
            ],
        )
        self.assertEqual(len(found), 2)


if __name__ == "__main__":
    unittest.main()
