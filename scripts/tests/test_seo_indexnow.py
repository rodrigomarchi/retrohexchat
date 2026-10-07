"""IndexNow by hand: the key read from the site, the batches, and stopping on a refusal."""

from __future__ import annotations

import unittest

from seo import indexnow

KEY = "da55d5dc4cbc878cc649e71681d80991"


class ReadKeyTest(unittest.TestCase):
    def test_reads_the_published_key(self):
        seen = []

        def fetch(url):
            seen.append(url)
            return f"{KEY}\n".encode()

        self.assertEqual(indexnow.read_key(fetch, "https://example.app/"), KEY)
        self.assertEqual(seen, ["https://example.app/indexnow.txt"])

    def test_a_page_that_is_not_a_key_is_refused(self):
        with self.assertRaises(indexnow.IndexNowError):
            indexnow.read_key(lambda _url: b"<html>Not found</html>", "https://example.app/")


class PayloadsTest(unittest.TestCase):
    def test_host_and_key_location_come_from_the_urls(self):
        [body] = indexnow.payloads(["https://example.app/", "https://example.app/faq", "https://example.app/"], KEY)
        self.assertEqual(
            body,
            {
                "host": "example.app",
                "key": KEY,
                "keyLocation": "https://example.app/indexnow.txt",
                "urlList": ["https://example.app/", "https://example.app/faq"],
            },
        )

    def test_batches_of_ten_thousand(self):
        bodies = indexnow.payloads([f"https://example.app/p{n}" for n in range(10_001)], KEY)
        self.assertEqual([len(b["urlList"]) for b in bodies], [10_000, 1])

    def test_more_than_one_host_is_refused(self):
        with self.assertRaises(indexnow.IndexNowError):
            indexnow.payloads(["https://example.app/", "https://other.app/"], KEY)

    def test_nothing_is_no_request(self):
        self.assertEqual(indexnow.payloads([], KEY), [])


class SubmitTest(unittest.TestCase):
    def test_every_batch_is_sent_while_accepted(self):
        sent = []

        def post(url, body):
            sent.append((url, len(body["urlList"])))
            return 202, ""

        bodies = indexnow.payloads([f"https://example.app/p{n}" for n in range(10_001)], KEY)
        self.assertEqual(indexnow.submit(bodies, post), [(10_000, 202, ""), (1, 202, "")])
        self.assertEqual(sent, [(indexnow.API, 10_000), (indexnow.API, 1)])

    def test_stops_at_the_first_refusal(self):
        bodies = indexnow.payloads([f"https://example.app/p{n}" for n in range(10_001)], KEY)
        results = indexnow.submit(bodies, lambda _url, _body: (403, "key not valid"))
        self.assertEqual(results, [(10_000, 403, "key not valid")])


if __name__ == "__main__":
    unittest.main()
