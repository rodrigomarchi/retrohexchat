#!/usr/bin/env python3
"""Measure code duplication across the umbrella and compare it with the last run.

    make dup.report                                   # reports/duplication/<UTC stamp>.{json,md}
    make dup.report BASELINE=reports/duplication/20261022T200000Z.json
    python3 scripts/duplication_report.py --skip-jscpd

Four instruments, each reading what the others cannot:

- ExDNA (``mix ex_dna``) reads the Elixir AST, so it sees a clone through
  renamed variables. Run twice: exact/renamed clones, and near-miss clones
  (``--literal-mode abstract --min-similarity 0.85 --normalize-pipes``).
- jscpd matches tokens. It covers the JS, the CSS, and the HEEx inside ``~H``
  sigils and ``.heex`` files, which ExDNA parses as opaque strings. JS clones
  are split into game-to-game (``js/lib/games/``) and the rest.
- A census of private helpers: ``defp name/arity`` defined in three or more
  modules is where a shared function was re-written instead of called.
- Markers: regexes for the copy patterns the refactor plan removes (topic
  strings built by hand, hand-made empty states, bots started outside the
  lifecycle...). Each one should only go down.

Every run writes new files named by its UTC time; nothing is overwritten. The
comparison is against ``--baseline`` when given, else the newest earlier run in
the output directory. Detectors exiting non-zero because they found clones is
expected and is not an error here.

Stdlib only, like every gate.
"""

from __future__ import annotations

import argparse
import collections
import json
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT / "reports" / "duplication"
DOMAIN_LIB = "apps/retro_hex_chat/lib"
WEB_LIB = "apps/retro_hex_chat_web/lib"
ASSETS = "apps/retro_hex_chat_web/assets"
JSCPD = "jscpd@4.3.0"

# The component gallery repeats its page skeleton by design.
EXDNA_IGNORE = ["**/showcase_live/**"]
# Help pages and icon SVGs repeat by design; the gallery as above.
HEEX_IGNORE = "**/help_content/**,**/icons/**,**/showcase_live/**"

# Names that are callbacks or conventional entry points, not helpers.
CENSUS_SKIP = {
    "mount", "render", "update", "handle_event", "handle_info", "handle_call",
    "handle_cast", "handle_continue", "handle_params", "init", "start_link",
    "child_spec", "terminate", "code_change", "perform", "execute", "handle",
    "syntax", "changeset", "run", "new", "validate", "description", "name",
    "usage", "help", "id", "call", "build", "apply", "parse", "format",
    "to_string", "cast", "dump", "load", "type", "equal?", "embed_as", "encode",
    "decode",
}

COMMENT_RE = re.compile(r"^\s*(?:#|//|\*|/\*)")
DEF_RE = re.compile(r"^\s*(defp|def)\s+([a-z_][a-zA-Z0-9_?!]*)\s*\(([^)]*)", re.M)

# name -> (regex, roots, file suffixes, paths excluded)
MARKERS = {
    "topic_strings_by_hand": (
        r'"(?:channel|user|game|arcade|chat_device_session):#\{',
        [DOMAIN_LIB, WEB_LIB], (".ex", ".heex"), ["retro_hex_chat/topics.ex"],
    ),
    "bot_started_outside_lifecycle": (
        r"Supervisor\.start_bot\(",
        [DOMAIN_LIB, WEB_LIB], (".ex",), ["bots/lifecycle.ex", "bots/supervisor.ex"],
    ),
    "private_html_escape": (
        r"defp html_escape(?:_attr)?\(",
        [DOMAIN_LIB, WEB_LIB], (".ex",), [],
    ),
    "hand_made_empty_state": (
        r'class="[^"]*\b[a-z_-]+-empty-state\b',
        [WEB_LIB], (".ex", ".heex"), [],
    ),
    "strftime_in_web": (
        r"Calendar\.strftime\(",
        [WEB_LIB], (".ex", ".heex"), ["app/chat_helpers.ex"],
    ),
    "audio_context_created": (
        r"new \(?\s*(?:window\.)?(?:webkit)?AudioContext\b",
        [f"{ASSETS}/js"], (".js",), [],
    ),
    "dead_game_input_code": (
        r"\b(?:encodePlayerInput|decodePlayerInput|_applyRemoteInput)\b",
        [f"{ASSETS}/js"], (".js",), [],
    ),
    # dom.js isEditableTarget is the one check; viewport_detect_hook differs on purpose.
    "editable_target_checks": (
        r"function\s+isEditableTarget\b|\.isContentEditable\b",
        [f"{ASSETS}/js"], (".js",), ["lib/ui/dom.js", "hooks/ui/viewport_detect_hook.js"],
    ),
}


def run(cmd: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)


def exdna(extra: list[str]) -> dict:
    cmd = ["mix", "ex_dna", DOMAIN_LIB, WEB_LIB, "--format", "json"]
    for glob in EXDNA_IGNORE:
        cmd += ["--ignore", glob]
    proc = run(cmd + extra)
    start = proc.stdout.find("{")
    if start < 0:
        raise RuntimeError(f"ex_dna produced no JSON:\n{proc.stderr[-2000:]}")
    return json.loads(proc.stdout[start:])


def exdna_summary(report: dict, top: int) -> dict:
    stats = report["stats"]
    clones = sorted(report["clones"], key=lambda c: -c["mass"] * len(c["fragments"]))
    return {
        "clones": stats["total_clones"],
        "duplicated_lines": stats["total_duplicated_lines"],
        "type_i": stats.get("type_i_count", 0),
        "type_ii": stats.get("type_ii_count", 0),
        "type_iii": stats.get("type_iii_count", 0),
        "top": [
            {
                "type": c["type"],
                "mass": c["mass"],
                "sites": [f'{rel(f["file"])}:{f["line"]}' for f in c["fragments"]],
            }
            for c in clones[:top]
        ],
    }


def jscpd(paths: list[str], args: list[str]) -> dict:
    with tempfile.TemporaryDirectory() as out:
        cmd = ["npx", "--yes", JSCPD, *paths, "--silent", "--reporters", "json", "--output", out, *args]
        proc = run(cmd)
        report = Path(out) / "jscpd-report.json"
        if not report.exists():
            raise RuntimeError(f"jscpd wrote no report:\n{proc.stdout[-1000:]}{proc.stderr[-1000:]}")
        return json.loads(report.read_text())


def jscpd_summary(report: dict, top: int, split=None) -> dict:
    total = report["statistics"]["total"]
    pairs: dict[tuple, list] = collections.defaultdict(lambda: [0, 0])
    split_lines = collections.Counter()
    for dup in report["duplicates"]:
        a, b = rel(dup["firstFile"]["name"]), rel(dup["secondFile"]["name"])
        key = tuple(sorted((a, b)))
        pairs[key][0] += dup["lines"]
        pairs[key][1] += 1
        if split:
            split_lines[split(a, b)] += dup["lines"]
    ranked = sorted(pairs.items(), key=lambda kv: -kv[1][0])
    summary = {
        "lines": total["lines"],
        "duplicated_lines": total["duplicatedLines"],
        "percentage": round(total["percentage"], 2),
        "clones": total["clones"],
        "top": [{"lines": v[0], "clones": v[1], "files": list(k)} for k, v in ranked[:top]],
    }
    for name, lines in split_lines.items():
        summary[f"duplicated_lines_{name}"] = lines
    return summary


def games_split(a: str, b: str) -> str:
    return "games" if "/js/lib/games/" in a and "/js/lib/games/" in b else "other"


def source_files(roots: list[str], suffixes: tuple, exclude: list[str]):
    for root in roots:
        for path in sorted((ROOT / root).rglob("*")):
            if path.suffix in suffixes and path.is_file():
                text = path.as_posix()
                if "/node_modules/" in text or any(text.endswith(e) for e in exclude):
                    continue
                yield path


def census(paths: list[tuple[str, str]], minimum: int = 3) -> list[dict]:
    """Private helpers (name/arity) defined in at least `minimum` modules.

    `paths` is a list of (label, source text). A public def of the same
    name/arity is reported alongside: it may be the function to call instead.
    """
    private: dict[tuple, set] = collections.defaultdict(set)
    public: dict[tuple, set] = collections.defaultdict(set)
    for label, text in paths:
        for kind, name, args in DEF_RE.findall(text):
            if name in CENSUS_SKIP:
                continue
            arity = args.count(",") + 1 if args.strip() else 0
            (private if kind == "defp" else public)[(name, arity)].add(label)
    rows = [
        {
            "helper": f"{name}/{arity}",
            "copies": len(files),
            "files": sorted(files),
            "public": sorted(public.get((name, arity), ())),
        }
        for (name, arity), files in private.items()
        if len(files) >= minimum
    ]
    return sorted(rows, key=lambda r: (-r["copies"], r["helper"]))


def markers() -> dict:
    counts = {}
    for name, (pattern, roots, suffixes, exclude) in MARKERS.items():
        regex = re.compile(pattern)
        sites = []
        for path in source_files(roots, suffixes, exclude):
            for number, line in enumerate(path.read_text(errors="ignore").splitlines(), 1):
                if regex.search(line) and not COMMENT_RE.match(line):
                    sites.append(f"{rel(path)}:{number}")
        counts[name] = {"count": len(sites), "sites": sites}
    return counts


def rel(path) -> str:
    text = str(path)
    root = str(ROOT) + "/"
    return text[len(root):] if text.startswith(root) else text


def flatten(report: dict) -> dict:
    """The numbers that are compared run to run, as one flat mapping."""
    flat = {}
    for section in ("exdna_exact", "exdna_near", "jscpd_js", "jscpd_css", "jscpd_heex"):
        for key, value in report.get(section, {}).items():
            if isinstance(value, (int, float)):
                flat[f"{section}.{key}"] = value
    if "census" in report:
        flat["census.helpers"] = len(report["census"])
        flat["census.copies"] = sum(r["copies"] for r in report["census"])
    for name, marker in report.get("markers", {}).items():
        flat[f"marker.{name}"] = marker["count"]
    return flat


def delta_rows(now: dict, before: dict | None) -> list[tuple[str, object, object, str]]:
    rows = []
    for key, value in now.items():
        previous = None if before is None else before.get(key)
        if previous is None:
            change = ""
        else:
            diff = round(value - previous, 2)
            change = "0" if diff == 0 else f"{diff:+g}"
        rows.append((key, value, "" if previous is None else previous, change))
    return rows


def previous_report(out: Path, baseline: str | None, current: Path) -> tuple[Path | None, dict | None]:
    if baseline:
        path = Path(baseline)
        return path, json.loads(path.read_text())
    earlier = sorted(p for p in out.glob("*.json") if p != current)
    if not earlier:
        return None, None
    return earlier[-1], json.loads(earlier[-1].read_text())


def markdown(report: dict, rows, against: Path | None) -> str:
    lines = [
        f"# Duplication report — {report['generated_at']}",
        "",
        f"Revision `{report['revision']}`. Compared with: "
        + (f"`{rel(against)}`" if against else "nothing (first run)."),
        "",
        "| Metric | Now | Before | Δ |",
        "|---|---:|---:|---:|",
    ]
    lines += [f"| {k} | {v} | {b} | {d} |" for k, v, b, d in rows]
    for section, title in (
        ("exdna_exact", "ExDNA — exact and renamed clones"),
        ("exdna_near", "ExDNA — near-miss clones"),
    ):
        if section in report:
            lines += ["", f"## {title}", ""]
            lines += [f"- `{c['type']}` mass {c['mass']}: {', '.join(c['sites'])}" for c in report[section]["top"]]
    for section, title in (("jscpd_js", "jscpd — JS"), ("jscpd_css", "jscpd — CSS"), ("jscpd_heex", "jscpd — Elixir/HEEx")):
        if section in report:
            lines += ["", f"## {title}", ""]
            lines += [f"- {p['lines']} lines, {p['clones']}×: {' ↔ '.join(p['files'])}" for p in report[section]["top"]]
    if "census" in report:
        lines += ["", "## Private helpers defined in 3+ modules", ""]
        for row in report["census"]:
            public = f" — public: {', '.join(row['public'])}" if row["public"] else ""
            lines.append(f"- `{row['helper']}` ×{row['copies']}: {', '.join(row['files'][:6])}{public}")
    if "markers" in report:
        lines += ["", "## Markers", ""]
        for name, marker in report["markers"].items():
            lines.append(f"- **{name}** ({marker['count']}): {', '.join(marker['sites'][:12])}")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--baseline", help="report JSON to compare with (default: newest earlier run)")
    parser.add_argument("--top", type=int, default=40, help="clones listed per section")
    parser.add_argument("--skip-jscpd", action="store_true", help="Elixir only (no npx/network)")
    args = parser.parse_args(argv)

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    report = {
        "generated_at": stamp,
        "revision": run(["git", "rev-parse", "--short", "HEAD"]).stdout.strip(),
    }

    # Every instrument is its own process reading the same tree, so they run
    # side by side: the report takes as long as its slowest instrument (the
    # near-miss ExDNA pass) rather than the sum of all of them.
    near = ["--literal-mode", "abstract", "--min-similarity", "0.85", "--normalize-pipes"]
    jobs = {
        "exdna_exact": lambda: exdna_summary(exdna([]), args.top),
        "exdna_near": lambda: exdna_summary(exdna(near), args.top),
        "census": lambda: census(
            [(rel(p), p.read_text(errors="ignore")) for p in source_files([DOMAIN_LIB, WEB_LIB], (".ex",), [])]
        ),
        "markers": markers,
    }
    if not args.skip_jscpd:
        jobs["jscpd_js"] = lambda: jscpd_summary(
            jscpd([f"{ASSETS}/js"], ["--format", "javascript", "--min-tokens", "50"]), args.top, games_split
        )
        jobs["jscpd_css"] = lambda: jscpd_summary(
            jscpd([f"{ASSETS}/css"], ["--format", "css", "--min-tokens", "50"]), args.top
        )
        jobs["jscpd_heex"] = lambda: jscpd_summary(
            jscpd(
                [DOMAIN_LIB, WEB_LIB],
                ["--formats-exts", "elixir:ex,heex", "--min-tokens", "80", "--ignore", HEEX_IGNORE],
            ),
            args.top,
        )

    print(f"Running {', '.join(jobs)} in parallel...", file=sys.stderr)
    with ThreadPoolExecutor(max_workers=len(jobs)) as pool:
        futures = {name: pool.submit(job) for name, job in jobs.items()}
        for name, future in futures.items():
            report[name] = future.result()

    json_path = out / f"{stamp}.json"
    against, before = previous_report(out, args.baseline, json_path)
    rows = delta_rows(flatten(report), None if before is None else flatten(before))
    json_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    md_path = out / f"{stamp}.md"
    md_path.write_text(markdown(report, rows, against))

    width = max(len(r[0]) for r in rows)
    print(f"\n{'metric':<{width}}  {'now':>8}  {'before':>8}  {'Δ':>7}")
    for key, value, previous, change in rows:
        print(f"{key:<{width}}  {value!s:>8}  {previous!s:>8}  {change:>7}")
    print(f"\nWrote {rel(json_path)} and {rel(md_path)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
