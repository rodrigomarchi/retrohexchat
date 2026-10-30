#!/usr/bin/env python3
"""Review what the Gettext catalogs already say, with Claude, through the Batches API.

    make i18n.claude.review ARGS="estimate --locales ja --domains landing,ui"
    make i18n.claude.review ARGS="submit   --run first --locales ja --domains landing,ui"
    make i18n.claude.review ARGS="collect  --run first"
    make i18n.claude.review ARGS="report   --run first"
    make i18n.claude.review ARGS="apply    --run first"

`submit` freezes the strings of a run, `collect` waits for the batches and judges
each change with the pipeline's own guards, `report` shows what came back and what
it cost, and `apply` writes the accepted changes through `catalogs.save_po`. Each
step resumes from the run's directory, so a stopped run loses nothing. Filling new
strings is `make i18n.translate ENGINE=claude`, not this.

Needs `make i18n.claude.venv` and ANTHROPIC_API_KEY in the environment or `.env`.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from dataclasses import asdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from i18n import catalogs, claude, locales, numerals  # noqa: E402
from seo.transport import env_value  # noqa: E402

RUNS = locales.REPO_ROOT / "tmp" / "i18n-claude"
POLL_SECONDS = 60


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("step", choices=["estimate", "submit", "collect", "report", "apply"])
    parser.add_argument("--run", default="", help="the run's name, its directory under tmp/i18n-claude")
    parser.add_argument("--locales", default="", help="comma-separated codes (default: all but en)")
    parser.add_argument("--domains", default="", help="comma-separated catalogs (default: all)")
    parser.add_argument("--no-wait", action="store_true", help="collect: stop if a batch is still running")
    parser.add_argument("--examples", type=int, default=30, help="report: changes to show per locale")
    return parser.parse_args(argv)


def selected_locales(args: argparse.Namespace) -> list:
    known = {locale.code: locale for locale in locales.enabled_locales() if locale.code != "en"}
    codes = [code.strip() for code in args.locales.split(",") if code.strip()] or list(known)
    unknown = [code for code in codes if code not in known]

    if unknown:
        raise SystemExit(f"Not a reviewable locale: {', '.join(unknown)}")

    return [known[code] for code in codes]


def catalog_paths(code: str, domains: str) -> list[Path]:
    wanted = {name.strip() for name in domains.split(",") if name.strip()}
    return [path for path in catalogs.po_files(code) if not wanted or path.stem in wanted]


def entry_forms(entry) -> list[str]:
    if entry.msgid_plural:
        return [entry.msgstr_plural.get(index, "") for index in sorted(entry.msgstr_plural)]

    return [entry.msgstr]


def collect_items(locale, domains: str) -> list[claude.Item]:
    """The distinct strings a review would read, in catalog order."""
    items: dict[str, claude.Item] = {}

    for path in catalog_paths(locale.code, domains):
        for entry in catalogs.translatable_entries(catalogs.load_po(path)):
            forms = entry_forms(entry)

            if not any(forms) or not claude.reviewable(entry.msgid, entry.msgctxt, locale.code):
                continue

            where = Path(entry.occurrences[0][0]).name if entry.occurrences else ""
            item = claude.Item(entry.msgid, entry.msgctxt, entry.msgid_plural or "", forms, where, path.stem)
            items.setdefault(item.key, item)

    return list(items.values())


def estimate(args: argparse.Namespace) -> int:
    total = 0

    for locale in selected_locales(args):
        items = collect_items(locale, args.domains)
        groups = claude.chunks(items)
        chars = sum(len(item.msgid) + sum(map(len, item.forms)) for item in items)
        total += chars
        print(f"{locale.code}: {len(items)} strings in {len(groups)} requests, {chars} characters")

    print(f"total characters read: {total}")
    return 0


def run_dir(args: argparse.Namespace) -> Path:
    if not args.run:
        raise SystemExit("--run is required")

    return RUNS / args.run


def client():
    import anthropic

    key = env_value("ANTHROPIC_API_KEY", locales.REPO_ROOT / ".env")

    if not key:
        raise SystemExit("ANTHROPIC_API_KEY is not set (environment or .env).")

    return anthropic.Anthropic(api_key=key)


def submit(args: argparse.Namespace, api=None) -> int:
    directory = run_dir(args)
    directory.mkdir(parents=True, exist_ok=True)
    api = api or client()

    for locale in selected_locales(args):
        plan_path = directory / f"{locale.code}.plan.json"

        if plan_path.exists():
            print(f"{locale.code}: already submitted")
            continue

        groups = claude.chunks(collect_items(locale, args.domains))
        requests = [
            {"custom_id": f"{locale.code}-{index:05d}", "params": claude.review_request(group, locale.code)}
            for index, group in enumerate(groups)
        ]
        batch = api.messages.batches.create(requests=requests)
        plan_path.write_text(
            json.dumps(
                {
                    "batch": batch.id,
                    "groups": {
                        request["custom_id"]: [asdict(item) for item in group]
                        for request, group in zip(requests, groups)
                    },
                },
                ensure_ascii=False,
            ),
            encoding="utf-8",
        )
        print(f"{locale.code}: {len(requests)} requests in {batch.id}")

    return 0


def plans(directory: Path) -> list[tuple[str, Path]]:
    return [(path.name.removesuffix(".plan.json"), path) for path in sorted(directory.glob("*.plan.json"))]


def judge_message(group: list[claude.Item], text: str, locale, verdict: dict) -> None:
    nplurals = numerals.parse_plural_forms(locale.plural_forms)[0] if locale.plural_forms else 1
    one_form = locale.code in locales.ONE_FORM_LOCALES

    for index, forms in claude.parse_changes(text).items():
        if index >= len(group):
            verdict["rejected"].append({"key": str(index), "reason": "an id it was never given"})
            continue

        item = group[index]
        finished, reason = claude.judge(item, forms, locale.code, one_form, nplurals)

        if reason:
            verdict["rejected"].append({"key": item.key, "reason": reason, "msgid": item.msgid[:120]})
        elif finished != item.forms:
            verdict["accepted"][item.key] = {"forms": finished, "was": item.forms, "msgid": item.msgid}


def collect_locale(code: str, plan_path: Path, api, verdict_path: Path) -> None:
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    locale = next(locale for locale in locales.enabled_locales() if locale.code == code)
    verdict = {"accepted": {}, "rejected": [], "failed": [], "usage": {"input_tokens": 0, "output_tokens": 0}}

    for result in api.messages.batches.results(plan["batch"]):
        custom_id = result.custom_id

        if result.result.type != "succeeded":
            verdict["failed"].append({"id": custom_id, "reason": result.result.type})
            continue

        message = result.result.message
        verdict["usage"]["input_tokens"] += message.usage.input_tokens
        verdict["usage"]["output_tokens"] += message.usage.output_tokens

        if message.stop_reason != "end_turn":
            verdict["failed"].append({"id": custom_id, "reason": message.stop_reason})
            continue

        group = [claude.Item(**item) for item in plan["groups"][custom_id]]
        text = next(block.text for block in message.content if block.type == "text")
        judge_message(group, text, locale, verdict)

    verdict_path.write_text(json.dumps(verdict, ensure_ascii=False, indent=0), encoding="utf-8")


def collect(args: argparse.Namespace, api=None) -> int:
    directory = run_dir(args)
    api = api or client()
    pending = {code: path for code, path in plans(directory)}

    while pending:
        for code, plan_path in list(pending.items()):
            verdict_path = directory / f"{code}.verdict.json"
            batch = json.loads(plan_path.read_text(encoding="utf-8"))["batch"]
            status = api.messages.batches.retrieve(batch)

            if status.processing_status == "ended":
                if not verdict_path.exists():
                    collect_locale(code, plan_path, api, verdict_path)

                print(f"{code}: ended")
                del pending[code]
            else:
                print(f"{code}: {status.processing_status}, {status.request_counts.processing} in progress")

        if pending:
            if args.no_wait:
                return 2

            time.sleep(POLL_SECONDS)

    return 0


def report(args: argparse.Namespace) -> int:
    directory = run_dir(args)
    spent = 0.0

    for code, plan_path in plans(directory):
        verdict_path = directory / f"{code}.verdict.json"

        if not verdict_path.exists():
            print(f"{code}: not collected")
            continue

        verdict = json.loads(verdict_path.read_text(encoding="utf-8"))
        read = sum(len(group) for group in json.loads(plan_path.read_text(encoding="utf-8"))["groups"].values())
        price = claude.cost(verdict["usage"])
        spent += price
        print(
            f"{code}: read={read} changed={len(verdict['accepted'])} refused={len(verdict['rejected'])} "
            f"failed_requests={len(verdict['failed'])} usage={verdict['usage']} cost=${price:.2f}"
        )

        for change in list(verdict["accepted"].values())[: args.examples]:
            print(f"  EN  {change['msgid'][:110]!r}\n  WAS {change['was'][0][:110]!r}\n  NOW {change['forms'][0][:110]!r}")

        for refusal in verdict["rejected"][:10]:
            print(f"  REFUSED {refusal}")

    print(f"total cost ${spent:.2f}")
    return 0


def apply(args: argparse.Namespace) -> int:
    directory = run_dir(args)

    for code, _plan_path in plans(directory):
        verdict_path = directory / f"{code}.verdict.json"

        if not verdict_path.exists():
            raise SystemExit(f"{code} is not collected yet")

        accepted = json.loads(verdict_path.read_text(encoding="utf-8"))["accepted"]
        written = 0

        for path in catalogs.po_files(code):
            po = catalogs.load_po(path)
            changed = 0

            for entry in catalogs.translatable_entries(po):
                key = claude.Item(entry.msgid, entry.msgctxt, entry.msgid_plural or "", []).key
                change = accepted.get(key)

                if not change or entry_forms(entry) != change["was"]:
                    continue

                if entry.msgid_plural:
                    entry.msgstr_plural = dict(zip(sorted(entry.msgstr_plural), change["forms"]))
                else:
                    entry.msgstr = change["forms"][0]

                changed += 1

            if changed:
                catalogs.save_po(po, path)
                written += changed

        print(f"{code}: {written} entries written")

    return 0


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    steps = {"estimate": estimate, "submit": submit, "collect": collect, "report": report, "apply": apply}
    return steps[args.step](args)


if __name__ == "__main__":
    sys.exit(main())
