#!/usr/bin/env python3
"""Fail on translations that are present but not usable.

The other gates ask whether a catalog is filled in. This one asks whether what
filled it means anything, catching the three ways machine translation fails
silently:

  collapse   one translation serving many unrelated sources
  degenerate a decoding loop ("kalıcı kalıcı kalıcı kalıcı")
  residue    an internal sentinel left in the shipped string
  break      a one-line source that came back as two
  negation   a source that says "cannot" whose translation says nothing of it
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from i18n import catalogs, glossary, locales  # noqa: E402
from i18n.protection import has_sentinel_residue  # noqa: E402
from i18n.quality import (  # noqa: E402
    COLLAPSE_THRESHOLD,
    find_collapses,
    find_shared_headings,
    introduced_degeneration,
    invented_break,
    lost_negation,
    looks_like_mojibake,
)


BASELINE = Path(__file__).parent / "i18n_negation_baseline.txt"


def baseline_key(code: str, source: str) -> str:
    """One line per accepted entry, keyed by locale and a hash of the source."""
    return f"{code}\t{hashlib.sha1(source.encode('utf-8')).hexdigest()}"


def read_baseline() -> set[str]:
    """Negations already lost before this guard existed.

    The guard found 105 of these in catalogues nobody had read, and a pass of
    the repair script fixed what the engine could fix. The rest are entries it
    reproduces the same way every time. Accepting them here is what lets the
    gate fail on the next one instead of being switched off.
    """
    if not BASELINE.exists():
        return set()

    return {
        line.strip()
        for line in BASELINE.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--locales",
        default=",".join(locales.codes()),
        help="Comma-separated locale codes (default: every enabled locale)",
    )
    parser.add_argument(
        "--collapse-threshold",
        type=int,
        default=COLLAPSE_THRESHOLD,
        help="Distinct sources sharing one translation before it counts as collapse",
    )
    parser.add_argument("--fail-on-findings", action="store_true")
    parser.add_argument(
        "--update-baseline",
        action="store_true",
        help="Rewrite the accepted lost-negation list from what is in the catalogues now",
    )
    parser.add_argument("--max-examples", type=int, default=3)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    selected = [code.strip() for code in args.locales.split(",") if code.strip()]

    if args.update_baseline:
        return write_baseline(selected)

    findings = 0

    for code in selected:
        findings += check_locale(code, args)

    print(f"findings={findings}")

    if findings and args.fail_on_findings:
        return 1

    return 0


def check_locale(code: str, args: argparse.Namespace) -> int:
    pairs: list[tuple[str, str]] = []
    degenerate: list[tuple[str, str]] = []
    residue: list[tuple[str, str]] = []
    drifted: list[tuple[str, str]] = []
    mojibake: list[tuple[str, str]] = []
    broken_lines: list[tuple[str, str]] = []
    unnegated: list[tuple[str, str]] = []
    curated = glossary.for_locale(code)
    accepted = read_baseline()

    for path in catalogs.po_files(code):
        for source, translated in catalogs.read_po_pairs(path):
            pairs.append((source, translated))

            if introduced_degeneration(source, translated):
                degenerate.append((source, translated))

            if has_sentinel_residue(translated):
                residue.append((source, translated))

            wanted = curated.get(source.strip())

            if wanted is not None and translated.strip() != wanted:
                drifted.append((source, f"{translated} (expected {wanted!r})"))

            if looks_like_mojibake(translated):
                mojibake.append((source, translated))

            if invented_break(source, translated) is not None:
                broken_lines.append((source, translated))

            if lost_negation(source, translated, code) and baseline_key(
                code, source
            ) not in accepted:
                unnegated.append((source, translated))

    collapses = find_collapses(pairs, args.collapse_threshold)
    headings = find_shared_headings(pairs, args.collapse_threshold)
    findings = (
        len(degenerate)
        + len(residue)
        + len(drifted)
        + len(mojibake)
        + len(broken_lines)
        + len(unnegated)
        + sum(len(sources) for sources in collapses.values())
        + sum(len(sources) for sources in headings.values())
    )

    if not findings:
        return 0

    print(f"\n{code}: {findings} findings")
    report_grouped("collapse", "translations", collapses, args.max_examples)
    report_grouped("injected heading", "headings", headings, args.max_examples)
    report_simple("degenerate", degenerate, args.max_examples)
    report_simple("residue", residue, args.max_examples)
    report_simple("glossary drift", drifted, args.max_examples)
    report_simple("mojibake", mojibake, args.max_examples)
    report_simple("invented line break", broken_lines, args.max_examples)
    report_simple("lost negation", unnegated, args.max_examples)
    return findings


def write_baseline(selected: list[str]) -> int:
    lines = []

    for code in selected:
        for path in catalogs.po_files(code):
            for source, translated in catalogs.read_po_pairs(path):
                if lost_negation(source, translated, code):
                    lines.append(baseline_key(code, source))

    body = "\n".join(sorted(set(lines)))
    BASELINE.write_text(
        "# Negations already lost when the guard was added. One line per locale\n"
        "# and source, keyed by hash. Never add to this by hand: a new finding is\n"
        "# a new defect, and the gate exists to say so.\n" + body + "\n",
        encoding="utf-8",
    )
    print(f"baseline={len(set(lines))}")
    return 0


def report_grouped(label: str, noun: str, groups: dict[str, set[str]], limit: int) -> None:
    if not groups:
        return

    total = sum(len(sources) for sources in groups.values())
    print(f"  {label}: {len(groups)} {noun} covering {total} sources")

    for value, sources in sorted(groups.items(), key=lambda item: -len(item[1]))[:limit]:
        print(f"    {len(sources)}x {value[:50]!r}")

        for source in sorted(sources)[:2]:
            print(f"        <- {source[:60]!r}")


def report_simple(label: str, items: list[tuple[str, str]], limit: int) -> None:
    if not items:
        return

    print(f"  {label}: {len(items)}")

    for source, translated in items[:limit]:
        print(f"    {source[:45]!r} -> {translated[:55]!r}")


if __name__ == "__main__":
    sys.exit(main())
