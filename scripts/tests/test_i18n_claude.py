"""The Claude engine: what a review may touch, and what it may write."""

from __future__ import annotations

import json
import unittest

from i18n import claude
from i18n.translator import ClaudeTranslator, build_back


def item(msgid="Save the topic", forms=("Guardar o tópico",), plural="", msgctxt=None):
    return claude.Item(msgid, msgctxt, plural, list(forms))


class ReviewableTest(unittest.TestCase):
    def test_the_glossary_keeps_its_labels(self):
        self.assertFalse(claude.reviewable("Language", None, "ja"))

    def test_a_sentence_is_reviewed(self):
        self.assertTrue(claude.reviewable("Open the channel and say hello.", None, "ja"))


class ChunksTest(unittest.TestCase):
    def test_a_group_stops_at_its_size(self):
        groups = claude.chunks([item(str(n)) for n in range(5)], size=2)

        self.assertEqual([len(group) for group in groups], [2, 2, 1])

    def test_a_group_stops_at_its_characters(self):
        groups = claude.chunks([item("x" * 50, ("y" * 50,)), item("z" * 50, ("w" * 50,))], max_chars=120)

        self.assertEqual(len(groups), 2)


class RequestTest(unittest.TestCase):
    def test_only_the_vocabulary_the_items_use_travels(self):
        note = claude.vocabulary([item("Pick a Language")], "ja")

        self.assertEqual(note["labels"].get("Language"), "言語")
        self.assertNotIn("Account", note["labels"])

    def test_a_request_asks_for_the_changes_as_structured_output(self):
        request = claude.review_request([item()], "pt_BR")

        self.assertEqual(request["model"], "claude-sonnet-5-5")
        self.assertEqual(request["output_config"]["format"]["schema"], claude.REVIEW_SCHEMA)
        self.assertIn("Brazilian Portuguese", request["system"])
        self.assertIn('"id": 0', request["messages"][0]["content"])

    def test_what_the_guards_will_demand_is_named_to_the_model(self):
        request = claude.review_request([item("Hello %{nick}", ("x",))], "pt_BR")

        self.assertIn('"keep_verbatim": ["%{nick}"]', request["messages"][0]["content"])

    def test_no_sentinel_reaches_the_model(self):
        self.assertNotIn("XPH", " ".join(claude.verbatim(item("A $5/month VPS at %{nick}/month", ("x",)))))

    def test_changes_are_read_by_id(self):
        text = json.dumps({"changes": [{"id": 3, "forms": ["a"]}]})

        self.assertEqual(claude.parse_changes(text), {3: ["a"]})


class JudgeTest(unittest.TestCase):
    def test_a_lost_placeholder_is_refused(self):
        forms, reason = claude.judge(item("Hello %{nick}", ("Olá %{nick}",)), ["Olá"], "pt_BR", False, 2)

        self.assertEqual(forms, [])
        self.assertIn("unusable", reason)

    def test_the_wrong_number_of_forms_is_refused(self):
        _forms, reason = claude.judge(item(forms=("a", "b"), plural="x"), ["a"], "pt_BR", False, 2)

        self.assertIn("forms", reason)

    def test_a_good_change_passes(self):
        forms, reason = claude.judge(item("Hello %{nick}", ("Olá",)), ["Olá, %{nick}"], "pt_BR", False, 2)

        self.assertIsNone(reason)
        self.assertEqual(forms, ["Olá, %{nick}"])

    def test_a_word_the_chat_requires_is_still_required(self):
        _forms, reason = claude.judge(item("Join a chat room", ("x",)), ["Entre num quarto"], "pt_BR", False, 2)

        self.assertIn("wrong words", reason)


class CostTest(unittest.TestCase):
    def test_a_million_of_each_at_batch_price(self):
        self.assertEqual(claude.cost({"input_tokens": 1_000_000, "output_tokens": 1_000_000}), 6.0)


class FakeBlock:
    type = "text"
    text = "olá"


class FakeMessage:
    stop_reason = "end_turn"
    content = [FakeBlock()]


class FakeMessages:
    def __init__(self):
        self.calls = []

    def create(self, **params):
        self.calls.append(params)
        return FakeMessage()


class FakeClient:
    def __init__(self):
        self.messages = FakeMessages()


class ClaudeTranslatorTest(unittest.TestCase):
    def test_it_answers_like_any_engine(self):
        fake = FakeClient()

        self.assertEqual(ClaudeTranslator("pt_BR", client=fake).translate("hello"), "olá")
        self.assertEqual(fake.messages.calls[0]["model"], claude.MODEL)
        self.assertIn("XSEGX", fake.messages.calls[0]["system"])

    def test_claude_is_not_read_back_through_argos(self):
        self.assertIsNone(build_back("pt_BR", "pt", "claude"))


if __name__ == "__main__":
    unittest.main()
