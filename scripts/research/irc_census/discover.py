#!/usr/bin/env python3
"""Rebuild networks.json — the survey frame — from netsplit.de's public directory.

This script fetches ONE thing from the web: where the servers are. Network names,
hostnames, ports and TLS flags — an address book, nothing more. No user count, no
channel count, no ranking from netsplit ever reaches the report; every number in
the census comes from a live /LIST against the server itself.

Curating the list by hand was the alternative, and it was worse: a hand-written
frame silently omits whatever the author never heard of, which in practice meant
the Bulgarian, Turkish, Malay and Brazilian networks. A derived frame has a knowable
bias (netsplit's own coverage) instead of an invisible one.

Usage:
  python3 discover.py [--top 100] [--out networks.json]
"""
import argparse
import html
import json
import os
import re
import sys
import threading
import urllib.parse
import urllib.request
from queue import Queue

HERE = os.path.dirname(os.path.abspath(__file__))
# netsplit serves an empty body to unrecognised agents and 406s on an explicit
# Accept header; this plain string is the one shape it answers.
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
TOP_URL = "https://netsplit.de/networks/top100.php"
SERVERS_URL = "https://netsplit.de/servers/?net=%s"


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=45) as r:
        return r.read().decode("utf-8", "replace")


def cells(row):
    return [html.unescape(re.sub(r"<[^>]+>", "", c)).strip()
            for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", row, re.S)]


def network_names(limit):
    """Ranked network names. The rank itself is discarded — it only decides who
    gets probed, never what the report claims."""
    page = get(TOP_URL)
    names = []
    for row in re.findall(r"<tr.*?</tr>", page, re.S):
        c = cells(row)
        if len(c) >= 4 and re.match(r"^\d+\.$", c[0]):
            names.append(c[3])
    return names[:limit]


def pick_server(net):
    """Return (host, port, tls) for a network, preferring a TLS main server."""
    try:
        page = get(SERVERS_URL % urllib.parse.quote(net))
    except Exception as e:
        print("  ! %s: %s" % (net, e), file=sys.stderr)
        return None
    candidates = []
    for row in re.findall(r"<tr.*?</tr>", page, re.S):
        c = cells(row)
        # Hostname | Port | SSL | MainServer
        if len(c) >= 4 and re.match(r"^[a-z0-9.\-]+\.[a-z]{2,}$", c[0], re.I) \
                and re.match(r"^\d+$", c[1]):
            candidates.append({"host": c[0].lower(), "port": int(c[1]),
                               "tls": c[2].lower() == "on",
                               "main": c[3].lower() == "yes"})
    if not candidates:
        return None
    candidates.sort(key=lambda s: (not s["main"], not s["tls"], s["port"]))
    best = candidates[0]
    return best["host"], best["port"], best["tls"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--top", type=int, default=100)
    ap.add_argument("--out", default=os.path.join(HERE, "networks.json"))
    ap.add_argument("--workers", type=int, default=6)
    args = ap.parse_args()

    # Optional hand-written colour: prior language and a one-line character note.
    ann_path = os.path.join(HERE, "annotations.json")
    annotations = {}
    if os.path.exists(ann_path):
        with open(ann_path) as fh:
            annotations = json.load(fh)

    names = network_names(args.top)
    print("directory lists %d networks" % len(names), file=sys.stderr)

    found, lock = {}, threading.Lock()
    q = Queue()
    for i, n in enumerate(names):
        q.put((i, n))

    def worker():
        while True:
            try:
                i, net = q.get_nowait()
            except Exception:
                return
            srv = pick_server(net)
            if srv:
                with lock:
                    found[net] = (i, srv)
            q.task_done()

    threads = [threading.Thread(target=worker, daemon=True) for _ in range(args.workers)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    out = []
    for net, (rank, (host, port, tls)) in sorted(found.items(), key=lambda kv: kv[1][0]):
        key = re.sub(r"[^a-z0-9]+", "", net.lower())
        ann = annotations.get(net) or annotations.get(key) or {}
        out.append({"name": key, "label": net, "host": host, "port": port, "tls": tls,
                    "prior_lang": ann.get("prior_lang"),
                    "blurb": ann.get("blurb", "")})

    with open(args.out, "w") as fh:
        json.dump(out, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    print("wrote %d networks to %s (%d had no reachable server entry)"
          % (len(out), args.out, len(names) - len(out)), file=sys.stderr)


if __name__ == "__main__":
    main()
