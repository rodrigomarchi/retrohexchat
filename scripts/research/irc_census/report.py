#!/usr/bin/env python3
"""Turn the harvested channel lists into a plain-text census report.

Reads   data/raw/*.jsonl + data/raw/_meta.json
Writes  data/channels.jsonl   (every channel, classified)
        data/report.txt       (the report)

Usage: python3 report.py [--top 40]
"""
import argparse
import json
import os
import statistics
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "data", "raw")
import classify  # noqa: E402  (local module, path-relative by design)

W = 100


def rule(ch="-"):
    return ch * W


def head(title):
    return "\n" + rule("=") + "\n" + title + "\n" + rule("=")


def table(headers, rows, aligns=None):
    cols = len(headers)
    aligns = aligns or ["l"] * cols
    widths = [len(h) for h in headers]
    srows = [[str(c) for c in r] for r in rows]
    for r in srows:
        for i, c in enumerate(r):
            widths[i] = max(widths[i], len(c))
    def fmt(cells):
        out = []
        for i, c in enumerate(cells):
            out.append(c.ljust(widths[i]) if aligns[i] == "l" else c.rjust(widths[i]))
        return "  ".join(out).rstrip()
    lines = [fmt(headers), fmt(["-" * w for w in widths])]
    lines += [fmt(r) for r in srows]
    return "\n".join(lines)


def pct(n, d):
    return "%.1f%%" % (100.0 * n / d) if d else "—"


def clip(s, n):
    s = " ".join((s or "").split())
    return s if len(s) <= n else s[: n - 1] + "…"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--top", type=int, default=40)
    args = ap.parse_args()

    with open(os.path.join(RAW, "_meta.json")) as fh:
        meta = json.load(fh)
    priors = {n["name"]: n.get("prior_lang") for n in meta["networks"]}
    blurbs = {n["name"]: n.get("blurb", "") for n in meta["networks"]}
    labels = {n["name"]: n.get("label", n["name"]) for n in meta["networks"]}

    chans = []
    for n in meta["networks"]:
        path = os.path.join(RAW, "%s.jsonl" % n["name"])
        if not os.path.exists(path):
            continue
        with open(path) as fh:
            for line in fh:
                line = line.strip()
                if line:
                    chans.append(classify.enrich(json.loads(line), priors.get(n["name"])))

    with open(os.path.join(HERE, "data", "channels.jsonl"), "w") as fh:
        for c in chans:
            fh.write(json.dumps(c, ensure_ascii=False) + "\n")

    # Spam traps advertise memberships they do not have. They stay in the raw
    # data and get their own section, but they are not part of any total.
    synthetic = [c for c in chans if c["synthetic"]]
    chans = [c for c in chans if not c["synthetic"]]

    # The subset the classifier can actually speak about: a topic to read and
    # enough members to matter. Everything else is reported, not interpreted.
    analysable = [c for c in chans if c["has_topic"] and c["users"] >= 5]

    out = []
    a = out.append
    total_ch = len(chans)
    occ = sum(c["users"] for c in chans)
    sized = lambda k: [c for c in chans if c["users"] >= k]  # noqa: E731

    # -- 0. header ---------------------------------------------------------
    a("IRC PUBLIC NETWORK CENSUS")
    a("collected: %s   |   wall time: %ss   |   networks probed: %d"
      % (meta["collected_at"], meta["wall_seconds"], len(meta["networks"])))
    a("")
    a("METHOD: an anonymous client connects to each network and issues /LIST — the")
    a("standard command that returns every publicly listed channel with its member")
    a("count and topic. Nothing is joined; no messages are sent or read.")
    a("")
    a("READ THIS BEFORE THE NUMBERS:")
    a("  * 'occupancy' = sum of per-channel member counts. A user in 5 channels is")
    a("    counted 5 times. It measures attention, NOT unique people.")
    a("  * channels set +s/+p (secret/private) never appear in LIST, so every count")
    a("    here is a floor, not a total.")
    a("  * language and subject are heuristic (see classify.py); each row carries the")
    a("    evidence that produced it, in data/channels.jsonl.")

    # -- 1. collection -----------------------------------------------------
    a(head("1. COLLECTION — WHICH NETWORKS ANSWERED"))
    rows = []
    for n in sorted(meta["networks"], key=lambda x: -x["channels"]):
        rows.append([n.get("label", n["name"]), n["status"], n["channels"], "%.0fs" % n["seconds"],
                     clip(n["detail"] or n["blurb"], 46)])
    a(table(["network", "status", "channels", "time", "detail / character"], rows,
            ["l", "l", "r", "r", "l"]))

    # -- 1b. synthetic channels -------------------------------------------
    if synthetic:
        a(head("1b. EXCLUDED — CHANNELS THAT EXIST TO BE COUNTED"))
        a("Some networks run spam traps: channels that advertise a huge membership")
        a("to poison the lists that spambots harvest. They are not places anyone is.")
        a("Left in, they would be the largest rooms on IRC and would rank their")
        a("network second overall. Excluded from every number in this report.")
        a("")
        syn_occ = sum(c["users"] for c in synthetic)
        rows = [[c["users"], c["network"], clip(c["channel"], 30), clip(c["topic"], 44)]
                for c in sorted(synthetic, key=lambda c: -c["users"])[:12]]
        a(table(["claimed", "network", "channel", "topic"], rows, ["r", "l", "l", "l"]))
        a("")
        a("%d such channels claiming %d members in total." % (len(synthetic), syn_occ))

    # -- 2. global shape ---------------------------------------------------
    a(head("2. GLOBAL SHAPE"))
    users = sorted((c["users"] for c in chans), reverse=True)
    a("channels listed ........ %d" % total_ch)
    a("total occupancy ........ %d (see caveat: not unique users)" % occ)
    a("median channel size .... %d" % (statistics.median(users) if users else 0))
    a("mean channel size ...... %.1f" % (occ / total_ch if total_ch else 0))
    a("")
    buckets = [(1, 1), (2, 2), (3, 4), (5, 9), (10, 24), (25, 49), (50, 99),
               (100, 249), (250, 999), (1000, 10 ** 9)]
    rows = []
    for lo, hi in buckets:
        grp = [c for c in chans if lo <= c["users"] <= hi]
        label = "%d" % lo if lo == hi else ("%d+" % lo if hi > 10 ** 8 else "%d-%d" % (lo, hi))
        rows.append([label, len(grp), pct(len(grp), total_ch),
                     sum(c["users"] for c in grp), pct(sum(c["users"] for c in grp), occ)])
    a(table(["size", "channels", "% of chans", "occupancy", "% of occ"], rows,
            ["l", "r", "r", "r", "r"]))
    a("")
    for k in (2, 5, 10, 50, 100):
        g = sized(k)
        a("channels with %4d+ members: %6d (%s of listed)  holding %s of all occupancy"
          % (k, len(g), pct(len(g), total_ch), pct(sum(c["users"] for c in g), occ)))
    top1 = users[: max(1, total_ch // 100)]
    a("")
    a("concentration: the top 1%% of channels (%d) hold %s of all occupancy."
      % (len(top1), pct(sum(top1), occ)))
    a("channels carrying a topic: %s — a set topic is the cheapest proxy for tending."
      % pct(sum(1 for c in chans if c["has_topic"]), total_ch))

    # -- 3. networks ranked ------------------------------------------------
    a(head("3. NETWORKS RANKED BY OCCUPANCY"))
    rows = []
    for n in meta["networks"]:
        cs = [c for c in chans if c["network"] == n["name"]]
        if not cs:
            continue
        o = sum(c["users"] for c in cs)
        big = [c for c in cs if c["users"] >= 10]
        rows.append([n.get("label", n["name"]), len(cs), o, pct(o, occ),
                     "%d" % statistics.median([c["users"] for c in cs]),
                     len(big), max(c["users"] for c in cs), clip(n["blurb"], 34)])
    rows.sort(key=lambda r: -r[2])
    a(table(["network", "chans", "occupancy", "share", "med", "10+", "biggest", "character"],
            rows, ["l", "r", "r", "r", "r", "r", "r", "l"]))

    # -- 4. biggest rooms --------------------------------------------------
    a(head("4. THE %d BIGGEST ROOMS ON IRC" % args.top))
    rows = []
    for c in sorted(chans, key=lambda c: -c["users"])[: args.top]:
        rows.append([c["users"], c["network"], clip(c["channel"], 24), c["lang"],
                     clip(c["subject"], 20), clip(c["topic"], 44) or "(no topic)"])
    a(table(["users", "network", "channel", "lang", "subject", "topic"], rows,
            ["r", "l", "l", "l", "l", "l"]))

    # -- 5. per-network flagships -----------------------------------------
    a(head("5. WHAT EACH NETWORK IS ACTUALLY FOR (top rooms per network)"))
    by_net = defaultdict(list)
    for c in chans:
        by_net[c["network"]].append(c)
    for net in sorted(by_net, key=lambda n: -sum(c["users"] for c in by_net[n])):
        cs = sorted(by_net[net], key=lambda c: -c["users"])[:8]
        a("")
        a("%s — %s" % (labels.get(net, net).upper(), blurbs.get(net, "")))
        a(table(["users", "channel", "lang", "subject", "topic"],
                [[c["users"], clip(c["channel"], 26), c["lang"], clip(c["subject"], 20),
                  clip(c["topic"], 40) or "(no topic)"] for c in cs],
                ["r", "l", "l", "l", "l"]))

    # -- 6. language -------------------------------------------------------
    a(head("6. LANGUAGE"))
    a("Counted three ways: all listed channels, channels with 5+ members (the ones")
    a("with a pulse), and share of occupancy.")
    a("")
    lang_ch, lang_occ, lang_live = Counter(), Counter(), Counter()
    for c in chans:
        lang_ch[c["lang"]] += 1
        lang_occ[c["lang"]] += c["users"]
        if c["users"] >= 5:
            lang_live[c["lang"]] += 1
    rows = []
    for lang, n in lang_occ.most_common():
        rows.append([lang, lang_ch[lang], pct(lang_ch[lang], total_ch), lang_live[lang],
                     n, pct(n, occ)])
    a(table(["lang", "channels", "% chans", "5+ chans", "occupancy", "% occ"], rows,
            ["l", "r", "r", "r", "r", "r"]))
    a("")
    a("NOTE: 'und' = no usable signal (usually a channel with no topic at all).")
    a("It is not a language; treat it as missing data leaning English. Cyrillic is")
    a("reported as 'ru' — the script does not distinguish Russian from Bulgarian,")
    a("Ukrainian or Serbian, so 'bg' below comes only from Bulgarian networks.")
    a("")
    a("Same table, restricted to the %d channels that have a topic AND 5+ members —"
      % len(analysable))
    a("the subset where the classifier actually has something to read:")
    a("")
    la_ch, la_occ = Counter(), Counter()
    for c in analysable:
        la_ch[c["lang"]] += 1
        la_occ[c["lang"]] += c["users"]
    a_occ = sum(c["users"] for c in analysable) or 1
    rows = [[l, la_ch[l], pct(la_ch[l], len(analysable)), n, pct(n, a_occ)]
            for l, n in la_occ.most_common(18)]
    a(table(["lang", "channels", "% chans", "occupancy", "% occ"], rows,
            ["l", "r", "r", "r", "r"]))

    # -- 7. subject --------------------------------------------------------
    a(head("7. SUBJECT"))
    subj_ch, subj_occ, subj_live = Counter(), Counter(), Counter()
    for c in chans:
        subj_ch[c["subject"]] += 1
        subj_occ[c["subject"]] += c["users"]
        if c["users"] >= 5:
            subj_live[c["subject"]] += 1
    rows = []
    for s, n in subj_occ.most_common():
        rows.append([s, subj_ch[s], pct(subj_ch[s], total_ch), subj_live[s], n, pct(n, occ)])
    a(table(["subject", "channels", "% chans", "5+ chans", "occupancy", "% occ"], rows,
            ["l", "r", "r", "r", "r", "r"]))

    a("")
    a("Same restriction — channels with a topic and 5+ members:")
    a("")
    sa_ch, sa_occ = Counter(), Counter()
    for c in analysable:
        sa_ch[c["subject"]] += 1
        sa_occ[c["subject"]] += c["users"]
    rows = [[s2, sa_ch[s2], pct(sa_ch[s2], len(analysable)), n, pct(n, a_occ)]
            for s2, n in sa_occ.most_common()]
    a(table(["subject", "channels", "% chans", "occupancy", "% occ"], rows,
            ["l", "r", "r", "r", "r"]))

    # -- 8. language x subject --------------------------------------------
    a(head("8. LANGUAGE × SUBJECT (occupancy, top cells)"))
    cross = Counter()
    for c in chans:
        cross[(c["lang"], c["subject"])] += c["users"]
    rows = [[l, s, n, pct(n, occ)] for (l, s), n in cross.most_common(30)]
    a(table(["lang", "subject", "occupancy", "% of all occ"], rows, ["l", "l", "r", "r"]))

    # -- 9. non-English flagships -----------------------------------------
    a(head("9. THE BIGGEST NON-ENGLISH ROOMS"))
    ne = [c for c in chans if c["lang"] not in ("en", "und")]
    rows = []
    for c in sorted(ne, key=lambda c: -c["users"])[:30]:
        rows.append([c["users"], c["lang"], c["network"], clip(c["channel"], 22),
                     clip(c["topic"], 46) or "(no topic)"])
    a(table(["users", "lang", "network", "channel", "topic"], rows,
            ["r", "l", "l", "l", "l"]))

    # -- 10. liveness ------------------------------------------------------
    a(head("10. LIVENESS SIGNALS"))
    ghost = [c for c in chans if c["users"] <= 2 and not c["has_topic"]]
    tended = [c for c in chans if c["users"] >= 5 and c["has_topic"]]
    a("ghost channels (<=2 members, no topic) ..... %6d  %s of listed"
      % (len(ghost), pct(len(ghost), total_ch)))
    a("tended rooms (5+ members and a topic) ...... %6d  %s of listed"
      % (len(tended), pct(len(tended), total_ch)))
    a("")
    a("Per network, share of channels that are tended rooms:")
    rows = []
    for net, cs in by_net.items():
        t = [c for c in cs if c["users"] >= 5 and c["has_topic"]]
        rows.append([labels.get(net, net), len(cs), len(t), pct(len(t), len(cs))])
    rows.sort(key=lambda r: -r[2])
    a(table(["network", "channels", "tended", "share"], rows, ["l", "r", "r", "r"]))

    # -- 11. shared vocabulary --------------------------------------------
    a(head("11. THE SAME ROOMS, EVERYWHERE"))
    a("Channel names that recur across independent networks. IRC has no shared")
    a("namespace, so this is convergence, not federation — the rooms people expect")
    a("to find on any network they join.")
    a("")
    spread = defaultdict(set)
    pop = Counter()
    for c in chans:
        key = c["channel"].lower().lstrip("#&!+")
        spread[key].add(c["network"])
        pop[key] += c["users"]
    rows = []
    for name, nets in sorted(spread.items(), key=lambda kv: (-len(kv[1]), -pop[kv[0]]))[:30]:
        rows.append(["#" + name, len(nets), pop[name]])
    a(table(["channel", "networks", "total occupancy"], rows, ["l", "r", "r"]))

    text = "\n".join(out) + "\n"
    path = os.path.join(HERE, "data", "report.txt")
    with open(path, "w") as fh:
        fh.write(text)
    print(text)
    print("\nreport: %s" % path)
    print("classified rows: %s" % os.path.join(HERE, "data", "channels.jsonl"))


if __name__ == "__main__":
    main()
