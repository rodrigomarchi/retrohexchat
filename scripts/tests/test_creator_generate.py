"""The character creator's PixelLab runner: which jobs are still to run, and
which frames a piece downloads to where."""

from __future__ import annotations

import os
import sys
import unittest

TOOLS = os.path.join(os.path.dirname(__file__), "..", "..", "virtual.space", "tools")
sys.path.insert(0, os.path.abspath(TOOLS))

import creator_generate as gen  # noqa: E402

CATALOG = {
    "master": "m",
    "dirs": ["south", "east"],
    "clips": [{"anim": "walk", "template": "walking-4-frames"}, {"anim": "sit", "pose": "seated", "steps": [1]}],
    "bases": {"av/bas": "m", "av/tun": "t"},
    "hair": [{"id": "lng", "character": "h"}],
    "headwear": [],
    "face": [],
}


def character(*animations):
    return {"rotation_urls": {"south": "r/s.png", "east": "r/e.png"}, "animations": list(animations)}


def animation(group, template, *dirs, frames=2):
    # What PixelLab answers: the template an animation was made from, and no
    # name of ours (it keeps none).
    return {"animation_group_id": group, "animation_type": template, "display_name": None,
            "directions": [{"direction": d, "frame_count": frames,
                            "frames": [f"{group}/{d}/{i}" for i in range(frames)]} for d in dirs]}


WALK = CATALOG["clips"][0]


class LayersTest(unittest.TestCase):
    def test_every_piece_is_a_named_layer(self):
        self.assertEqual(gen.layers(CATALOG), [("base-av-bas", "m"), ("base-av-tun", "t"), ("hair-lng", "h")])


class SourcesTest(unittest.TestCase):
    def test_a_clip_is_known_by_the_template_pixellab_says_made_it(self):
        ch = character(animation("g1", "walking-4-frames", "south"), animation("g2", "breathing-idle", "east"))
        self.assertEqual(gen.done_directions(ch, None, WALK), {"south"})

    def test_the_registered_group_wins_over_a_leftover_of_the_same_template(self):
        ch = character(animation("old", "walking-4-frames", "south", "east"),
                       animation("g1", "walking-4-frames", "south"))
        sources = gen.clip_sources(ch, "g1", WALK)
        self.assertEqual(sources["south"][0]["animation_group_id"], "g1")
        self.assertEqual(sources["east"][0]["animation_group_id"], "old")  # g1 has no east

    def test_unregistered_the_fullest_group_answers_and_new_facings_join_it(self):
        ch = character(animation("small", "walking-4-frames", "south"),
                       animation("big", "walking-4-frames", "south", "east"))
        self.assertEqual(gen.clip_sources(ch, None, WALK)["south"][0]["animation_group_id"], "big")
        self.assertEqual(gen.append_group(ch, None, WALK), "big")
        self.assertEqual(gen.append_group(ch, "g9", WALK), "g9")
        self.assertIsNone(gen.append_group(character(), None, WALK))

    def test_a_facing_with_no_frames_yet_is_not_done(self):
        ch = character(animation("g1", "walking-4-frames", "south", frames=0))
        self.assertEqual(gen.done_directions(ch, "g1", WALK), set())


class PlanTest(unittest.TestCase):
    def test_only_what_is_missing_is_planned(self):
        characters = {
            "m": character(animation("g1", "walking-4-frames", "south")),
            "t": character(animation("g2", "walking-4-frames", "south", "east")),
            "h": character(animation("g3", "breathing-idle", "south", "east")),
        }
        registry = {"characters": {"m": {"groups": {"walk": "g1"}}}}
        posed = {("base-av-bas", "sit", "south")}
        jobs = gen.plan(CATALOG, registry, characters, lambda l, a, d: (l, a, d) in posed)
        self.assertEqual(
            [(layer, clip["anim"], d) for layer, _cid, clip, d in jobs],
            [("base-av-bas", "walk", "east"), ("base-av-bas", "sit", "east"),
             ("base-av-tun", "sit", "south"), ("base-av-tun", "sit", "east"),
             ("hair-lng", "walk", "south"), ("hair-lng", "walk", "east"),
             ("hair-lng", "sit", "south"), ("hair-lng", "sit", "east")],
        )


class DownloadsTest(unittest.TestCase):
    def test_rotations_and_the_clips_frames_and_where_they_came_from(self):
        ch = character(animation("g1", "walking-4-frames", "east"), animation("x", "breathing-idle", "south"))
        registry = {"characters": {"m": {"groups": {"walk": "g1"}}}}
        rels = [rel for _url, rel in gen.frame_downloads(CATALOG, registry, "base-av-bas", "m", ch)]
        self.assertEqual(rels, [
            os.path.join("base-av-bas", "rotations", "east.png"),
            os.path.join("base-av-bas", "rotations", "south.png"),
            os.path.join("base-av-bas", "walk", "east", "0.png"),
            os.path.join("base-av-bas", "walk", "east", "1.png"),
        ])
        self.assertEqual(gen.frame_sources(CATALOG, registry, "m", ch),
                         {"walk": {"east": {"template": "walking-4-frames", "group": "g1"}}})


class LockTest(unittest.TestCase):
    def setUp(self):
        import tempfile
        self.path = os.path.join(tempfile.mkdtemp(), "lock")

    def test_one_run_at_a_time(self):
        gen.acquire_lock(self.path, pid=10, alive=lambda p: True, others=lambda p: [])
        with self.assertRaises(gen.Locked):
            gen.acquire_lock(self.path, pid=11, alive=lambda p: True, others=lambda p: [])

    def test_a_run_started_without_the_lock_counts_too(self):
        with self.assertRaises(gen.Locked):
            gen.acquire_lock(self.path, pid=11, alive=lambda p: False, others=lambda p: [99])

    def test_a_lock_left_by_a_run_that_died_is_taken_over(self):
        gen.acquire_lock(self.path, pid=10, alive=lambda p: True, others=lambda p: [])
        gen.acquire_lock(self.path, pid=11, alive=lambda p: False, others=lambda p: [])
        with open(self.path) as handle:
            self.assertEqual(handle.read(), "11")

    def test_the_shell_that_started_this_run_is_not_another_run(self):
        ps = "\n".join([
            "  1     0 /sbin/launchd",
            " 50     1 /bin/zsh -c PIXELLAB_TOKEN=x python3 -u creator_generate.py run --budget 9",
            " 51    50 /usr/bin/Python -u creator_generate.py run --budget 9",
            " 70     1 /bin/zsh -c python3 creator_generate.py run",
            " 71    70 /opt/python3.14/Python creator_generate.py run",
            " 80     1 grep creator_generate.py run",
        ])
        self.assertEqual(gen.other_runs(ps, 51), [71])
        self.assertEqual(gen.other_runs(ps, 99), [51, 71])


class PendingTest(unittest.TestCase):
    def test_jobs_sent_are_kept_on_disk_until_seen_to_end(self):
        import tempfile
        path = os.path.join(tempfile.mkdtemp(), "pending.json")
        job = {"layer": "hair-lng", "cid": "h", "anim": "wave", "dir": "south"}
        gen.save_pending(path, {"j1": job})
        self.assertEqual(gen.load_pending(path), {"j1": job})
        gen.save_pending(path, {})
        self.assertFalse(os.path.exists(path))
        self.assertEqual(gen.load_pending(path), {})


class BudgetTest(unittest.TestCase):
    def test_every_job_sent_counts_against_the_budget(self):
        # 16 sent so far: one more of 3 makes 19.
        self.assertTrue(gen.within_budget(16, 3, 19))
        self.assertFalse(gen.within_budget(16, 3, 18))

    def test_a_clip_costs_what_it_was_measured_at(self):
        self.assertEqual(gen.cost_of({"anim": "walk", "template": "walking-4-frames"}), 3)
        self.assertEqual(gen.cost_of({"anim": "sit", "pose": "seated", "steps": [0.5, 1]}), 2)
        self.assertEqual(gen.cost_of({"anim": "wave", "pose": "wave", "steps": [0.5, 1, 2, 1, 2, 0.5]}), 3)


class RegistryTest(unittest.TestCase):
    def test_two_runs_keep_each_others_groups(self):
        on_disk = {"characters": {"a": {"layer": "hair-a", "groups": {"walk": "g1"}},
                                  "b": {"layer": "hat-b", "groups": {"idle": "g2"}}}}
        mine = {"characters": {"a": {"layer": "hair-a", "groups": {"idle": "g3"}},
                               "c": {"layer": "face-c", "groups": {"walk": "g4"}}}}
        merged = gen.merge_registry(on_disk, mine)
        self.assertEqual(merged["characters"]["a"]["groups"], {"walk": "g1", "idle": "g3"})
        self.assertEqual(merged["characters"]["b"]["groups"], {"idle": "g2"})
        self.assertEqual(merged["characters"]["c"]["groups"], {"walk": "g4"})

    def test_facings_generated_again_survive_a_save_and_the_later_round_wins(self):
        on_disk = {"characters": {"a": {"layer": "hair-a", "groups": {},
                                        "redone": {"walk": {"east": {"round": 2, "group": "g2"}}}}}}
        mine = {"characters": {"a": {"layer": "hair-a", "groups": {},
                                     "redone": {"walk": {"east": {"round": 1, "group": "g1"},
                                                         "south": {"round": 1, "group": "g3"}}}}}}
        merged = gen.merge_registry(on_disk, mine)
        self.assertEqual(merged["characters"]["a"]["redone"]["walk"],
                         {"east": {"round": 2, "group": "g2"}, "south": {"round": 1, "group": "g3"}})
        self.assertEqual(gen.merge_registry(on_disk, {"characters": {}})["characters"]["a"]["redone"],
                         on_disk["characters"]["a"]["redone"])


class NetworkTest(unittest.TestCase):
    def test_ipv4_addresses_are_tried_first(self):
        import socket
        v6 = (socket.AF_INET6, socket.SOCK_STREAM, 6, "", ("2606::1", 443, 0, 0))
        v4 = (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("1.2.3.4", 443))
        self.assertEqual(gen.ipv4_first([v6, v4, v6]), [v4, v6, v6])


class PosedDescriptionTest(unittest.TestCase):
    MASTER = "a bald mannequin, no hair, no accessories"

    def state(self, edit):
        return {"prompt": self.MASTER, "style_settings": {"state_source": {"edit_description": edit}}}

    def test_a_piece_is_described_by_its_own_edit_not_the_bald_master(self):
        text = gen.posed_description(self.state("with an afro, the hair is magenta; everything else unchanged"),
                                     "hair-afr")
        self.assertIn("with an afro, the hair is magenta", text)
        self.assertNotIn("bald", text)
        self.assertNotIn("unchanged", text)

    def test_an_outfit_keeps_the_bald_head_the_overlays_go_on(self):
        text = gen.posed_description(self.state("wearing a tunic; same face"), "base-av-tun")
        self.assertTrue(text.endswith("wearing a tunic, with a completely bald head"))

    def test_the_master_has_no_edit_and_keeps_its_prompt(self):
        self.assertEqual(gen.posed_description({"prompt": self.MASTER}, "base-av-bas"), self.MASTER)

    def test_long_edits_are_cut_at_a_word(self):
        text = gen.posed_description(self.state("wearing " + "a very long cloak " * 30), "hat-x")
        self.assertLessEqual(len(text), 300)
        self.assertFalse(text.endswith(" "))
        self.assertTrue(text.endswith("cloak") or text.endswith("long") or text.endswith("very") or text.endswith("a"))


class RedoTest(unittest.TestCase):
    def test_a_facing_sent_back_comes_from_its_new_group_once_it_has_frames(self):
        ch = character(animation("g1", "walking-4-frames", "south", "east"),
                       animation("new", "walking-4-frames", "east"))
        sources = gen.clip_sources(ch, "g1", WALK, {"east": "new"})
        self.assertEqual(sources["east"][0]["animation_group_id"], "new")
        self.assertEqual(sources["south"][0]["animation_group_id"], "g1")
        empty = character(animation("g1", "walking-4-frames", "east"),
                          animation("new", "walking-4-frames", "east", frames=0))
        self.assertEqual(gen.clip_sources(empty, "g1", WALK, {"east": "new"})["east"][0]["animation_group_id"], "g1")

    def test_only_facings_not_yet_redone_in_their_round_are_jobs(self):
        registry = {"characters": {"h": {"redone": {"walk": {"east": {"round": 1, "group": "new"}}}}}}
        redo = [{"layer": "hair-lng", "anim": "walk", "dir": "east"},
                {"layer": "hair-lng", "anim": "walk", "dir": "south"},
                {"layer": "hair-lng", "anim": "sit", "dir": "east", "round": 2}]
        jobs = gen.redo_jobs(CATALOG, registry, redo)
        self.assertEqual([(j[0], j[2]["anim"], j[3], j[4]) for j in jobs],
                         [("hair-lng", "walk", "south", 1), ("hair-lng", "sit", "east", 2)])
        bumped = [{"layer": "hair-lng", "anim": "walk", "dir": "east", "round": 2}]
        self.assertEqual(len(gen.redo_jobs(CATALOG, registry, bumped)), 1)

    def test_a_redo_naming_nothing_in_the_catalog_is_refused(self):
        with self.assertRaises(ValueError):
            gen.redo_jobs(CATALOG, {}, [{"layer": "hair-x", "anim": "walk", "dir": "east"}])

    def test_a_redo_is_recorded_with_its_round_and_group(self):
        registry = {"characters": {}}
        gen.record_redo(registry, "hair-lng", "h", "walk", "east", 1, "new")
        self.assertEqual(gen.redone_groups(registry, "h", "walk"), {"east": "new"})
        gen.record_redo(registry, "hair-lng", "h", "sit", "east", 1, None)
        self.assertEqual(gen.redone_groups(registry, "h", "sit"), {})

    def test_frames_from_another_group_than_on_disk_are_stale(self):
        old = {"walk": {"east": {"group": "g1"}, "south": {"group": "g1"}}}
        new = {"walk": {"east": {"group": "new"}, "south": {"group": "g1"}}, "idle": {"east": {"group": "i"}}}
        self.assertEqual(gen.changed_facings(old, new), [("walk", "east")])


class RetryTest(unittest.TestCase):
    def test_a_service_error_is_tried_again_and_a_refusal_is_not(self):
        import urllib.error
        calls = []

        def flaky():
            calls.append(1)
            if len(calls) < 3:
                raise urllib.error.HTTPError("u", 520, "busy", {}, None)
            return "ok"

        self.assertEqual(gen._retrying(flaky, sleep=lambda _s: None), "ok")
        self.assertEqual(len(calls), 3)

        def refused():
            raise urllib.error.HTTPError("u", 404, "gone", {}, None)

        with self.assertRaises(urllib.error.HTTPError):
            gen._retrying(refused, sleep=lambda _s: None)


if __name__ == "__main__":
    unittest.main()
