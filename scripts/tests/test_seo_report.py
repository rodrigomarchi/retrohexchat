"""The shared report: problems derived from normalised sections, and its rendering."""

from __future__ import annotations

import json
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from seo import report as rpt

NOW = datetime(2026, 10, 7, 11, 20, 3, tzinfo=timezone.utc)


def inspected(url: str, state: str, last_crawled: str | None = None) -> dict:
    return {"url": url, "state": state, "discovered": None, "last_crawled": last_crawled, "detail": None}


def kinds(report: dict) -> list[str]:
    return [p["kind"] for p in rpt.derive_problems(report)]


class NewReportTest(unittest.TestCase):
    def test_every_section_starts_unavailable(self):
        report = rpt.new_report("bing", "https://example.app/", NOW)
        self.assertEqual(report["generated_at"], "2026-10-07T11:20:03+00:00")
        for section in ("sitemaps", "crawl_issues", "crawl_stats", "inspection", "performance"):
            self.assertIsNone(report[section])
        self.assertEqual(rpt.derive_problems(report), [])

    def test_generated_at_is_utc_whatever_the_input_zone(self):
        local = datetime.fromisoformat("2026-10-07T08:20:03-03:00")
        self.assertEqual(rpt.new_report("bing", "s", local)["generated_at"], "2026-10-07T11:20:03+00:00")


class DeriveProblemsTest(unittest.TestCase):
    def setUp(self):
        self.report = rpt.new_report("bing", "https://example.app/", NOW)

    def test_an_empty_sitemap_list_is_an_error_but_an_unavailable_one_is_not(self):
        self.report["sitemaps"] = []
        self.assertEqual(kinds(self.report), ["no_sitemap"])
        self.report["sitemaps"] = None
        self.assertEqual(kinds(self.report), [])

    def test_a_sitemap_that_failed_or_has_errors(self):
        self.report["sitemaps"] = [
            {"url": "a.xml", "type": "Sitemap", "status": "Success", "submitted": None, "last_read": None,
             "url_count": 1, "errors": None, "warnings": None},
            {"url": "b.xml", "type": "Sitemap", "status": "Failed", "submitted": None, "last_read": None,
             "url_count": 0, "errors": 2, "warnings": 1},
        ]
        problems = rpt.derive_problems(self.report)
        self.assertEqual([p["kind"] for p in problems], ["sitemap_errors", "sitemap_status", "sitemap_warnings"])
        self.assertTrue(all("b.xml" in p["message"] for p in problems))

    def test_crawl_issues_group_by_issue_and_redirects_are_warnings(self):
        self.report["crawl_issues"] = [
            {"url": "/a", "issues": ["http_4xx"], "http_status": 404},
            {"url": "/b", "issues": ["http_4xx", "redirect_301"], "http_status": 404},
        ]
        problems = {p["kind"]: p for p in rpt.derive_problems(self.report)}
        self.assertEqual(problems["crawl_http_4xx"]["severity"], "error")
        self.assertEqual(problems["crawl_http_4xx"]["urls"], ["/a", "/b"])
        self.assertEqual(problems["crawl_redirect_301"]["severity"], "warning")

    def test_healthy_inspection_states_raise_nothing(self):
        self.report["inspection"] = {"sitemap_urls": 2, "urls": [inspected("/a", "indexed"), inspected("/b", "crawled")]}
        self.assertEqual(kinds(self.report), [])

    def test_each_unhealthy_state_is_one_problem_listing_its_urls(self):
        self.report["inspection"] = {
            "sitemap_urls": 9,
            "urls": [inspected("/a", "unknown"), inspected("/b", "unknown"), inspected("/c", "error")],
        }
        problems = {p["kind"]: p for p in rpt.derive_problems(self.report)}
        self.assertEqual(problems["inspection_unknown"]["urls"], ["/a", "/b"])
        self.assertEqual(problems["inspection_unknown"]["message"], "2 of 3 inspected URL(s) are unknown.")
        self.assertEqual(problems["inspection_error"]["severity"], "error")

    def test_stale_is_measured_from_the_report_date_not_the_clock(self):
        self.report["inspection"] = {
            "sitemap_urls": 2,
            "urls": [
                inspected("/old", "crawled", "2026-08-07T00:00:00+00:00"),
                inspected("/fresh", "crawled", "2026-08-08T00:00:00+00:00"),
            ],
        }
        problems = {p["kind"]: p for p in rpt.derive_problems(self.report)}
        self.assertEqual(problems["stale_crawl"]["urls"], ["/old"])

    def test_performance_without_impressions_and_low_ctr_queries(self):
        self.report["performance"] = {"totals": rpt.perf_row("total", 0, 0, None), "queries": [], "pages": []}
        self.assertEqual(kinds(self.report), ["no_traffic"])
        self.report["performance"] = {
            "totals": rpt.perf_row("total", 1, 300, 4.0),
            "queries": [rpt.perf_row("irc online", 0, 200, 9.0), rpt.perf_row("mirc", 1, 50, 2.0)],
            "pages": [],
        }
        problems = {p["kind"]: p for p in rpt.derive_problems(self.report)}
        self.assertEqual(list(problems), ["low_ctr_query"])
        self.assertEqual(problems["low_ctr_query"]["urls"], ["irc online"])

    def test_problems_are_ordered_error_warning_info(self):
        self.report["sitemaps"] = []
        self.report["performance"] = {"totals": rpt.perf_row("total", 0, 0, None), "queries": [], "pages": []}
        self.report["inspection"] = {"sitemap_urls": 1, "urls": [inspected("/a", "unknown")]}
        severities = [p["severity"] for p in rpt.derive_problems(self.report)]
        self.assertEqual(severities, ["error", "warning", "info"])


class PerfRowTest(unittest.TestCase):
    def test_ctr_and_rounding(self):
        self.assertEqual(
            rpt.perf_row("q", 3, 40, 4.26),
            {"key": "q", "clicks": 3, "impressions": 40, "ctr": 0.075, "position": 4.3},
        )

    def test_no_impressions_is_zero_ctr(self):
        self.assertEqual(rpt.perf_row("q", 0, 0, None)["ctr"], 0.0)


class RenderTest(unittest.TestCase):
    def test_unavailable_and_empty_sections_read_differently(self):
        report = rpt.new_report("bing", "https://example.app/", NOW)
        report["crawl_issues"] = []
        text = rpt.render_markdown(rpt.finalize(report))
        self.assertIn("# SEO report — bing — https://example.app/", text)
        self.assertIn("Generated 2026-10-07T11:20:03+00:00", text)
        self.assertIn("_No crawl issues reported._", text)
        self.assertIn("## Sitemaps\n\n_Not available from bing._", text)
        self.assertIn("_None found._", text)

    def test_long_url_lists_are_cut_with_a_pointer_to_the_json(self):
        report = rpt.new_report("bing", "s", NOW)
        report["inspection"] = {
            "sitemap_urls": 30,
            "urls": [inspected(f"/p{i}", "unknown") for i in range(rpt.URLS_PER_PROBLEM + 3)],
        }
        text = rpt.render_markdown(rpt.finalize(report))
        self.assertIn("… and 3 more (see the JSON)", text)

    def test_pipes_in_cells_are_escaped(self):
        report = rpt.new_report("bing", "s", NOW)
        report["crawl_issues"] = [{"url": "/a|b", "issues": ["http_4xx"], "http_status": 404}]
        self.assertIn("/a\\|b", rpt.render_markdown(report))


class WriteTest(unittest.TestCase):
    def test_files_are_named_by_generation_time_and_never_overwrite(self):
        out = Path(tempfile.mkdtemp())
        first = rpt.finalize(rpt.new_report("bing", "s", NOW))
        later = rpt.finalize(rpt.new_report("bing", "s", NOW.replace(second=4)))
        json_path, md_path = rpt.write(first, out)
        rpt.write(later, out)
        self.assertEqual(json_path.name, "20261007T112003Z-bing.json")
        self.assertEqual(md_path.name, "20261007T112003Z-bing.md")
        self.assertEqual(len(list(out.iterdir())), 4)
        self.assertEqual(json.loads(json_path.read_text())["generated_at"], "2026-10-07T11:20:03+00:00")


if __name__ == "__main__":
    unittest.main()
