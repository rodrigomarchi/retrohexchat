#!/usr/bin/env python3
"""Harvest the public channel list (/LIST) of every network in networks.json.

Each network is contacted in its own thread by an anonymous, read-only client:
register, LIST, quit. Nothing is joined, nothing is said.

Output:
  data/raw/<network>.jsonl   one JSON object per channel
  data/raw/_meta.json        per-network status, counts, timings

Usage:
  python3 collect.py [--only net1,net2] [--timeout 400]
"""
import argparse
import json
import os
import random
import re
import socket
import ssl
import sys
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "data", "raw")

# Numerics we care about.
RPL_WELCOME, RPL_ENDOFMOTD, ERR_NOMOTD = "001", "376", "422"
RPL_LISTSTART, RPL_LIST, RPL_LISTEND = "321", "322", "323"
ERR_NICKNAMEINUSE, RPL_TRYAGAIN, ERR_TOOMANYMATCHES = "433", "263", "416"
ERR_UNKNOWNCOMMAND = "421"
FATAL = {"464": "password required", "465": "banned from network",
         "466": "you will be banned", "489": "restricted"}

PRINTLOCK = threading.Lock()


def log(net, msg):
    with PRINTLOCK:
        print("[%-12s] %s" % (net, msg), file=sys.stderr, flush=True)


class Harvest:
    """One anonymous LIST session against one network."""

    def __init__(self, spec, hard_timeout, idle_timeout, cooldown=70):
        self.spec = spec
        self.net = spec["name"]
        self.hard_timeout = hard_timeout
        self.idle_timeout = idle_timeout
        self.cooldown = cooldown
        self.channels = []
        self.status = "pending"
        self.detail = ""
        self.server = ""
        self.elapsed = 0.0

    # -- connection -------------------------------------------------------
    def connect(self):
        sock = socket.create_connection((self.spec["host"], self.spec["port"]), timeout=30)
        if self.spec["tls"]:
            ctx = ssl.create_default_context()
            # Many surviving networks run self-signed or long-expired certs;
            # we read public data only, so cert identity is not a trust anchor.
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
            sock = ctx.wrap_socket(sock, server_hostname=self.spec["host"])
        sock.settimeout(5)
        return sock

    def send(self, line):
        self.sock.sendall((line + "\r\n").encode("utf-8", "replace"))

    # -- protocol ---------------------------------------------------------
    def run(self):
        started = time.time()
        try:
            self.sock = self.connect()
        except Exception as e:
            self.status, self.detail = "unreachable", "%s: %s" % (type(e).__name__, e)
            log(self.net, "unreachable — %s" % self.detail)
            return self

        nick = "rsrch%04d" % random.randint(0, 9999)
        self.send("NICK %s" % nick)
        self.send("USER %s 0 * :irc census" % nick)

        buf = b""
        registered_at = None
        list_sent = False
        attempts = 0
        retried = False
        retry_at = None          # securelist cooldown: when to ask a second time
        last_row = None
        done = False

        def request_list():
            self.send("LIST")

        while not done and time.time() - started < self.hard_timeout:
            try:
                data = self.sock.recv(65536)
                if not data:
                    self.status = self.status if self.channels else "closed"
                    self.detail = self.detail or "server closed the connection"
                    break
                buf += data
            except socket.timeout:
                now = time.time()
                if self.channels and last_row and now - last_row > self.idle_timeout:
                    self.status, self.detail = "partial", "output stalled after %d rows" % len(self.channels)
                    break
                if retry_at and now >= retry_at:
                    retry_at = None
                    attempts += 1
                    request_list()
                if registered_at and not list_sent and now - registered_at > 8:
                    request_list()
                    list_sent = True
                    attempts = 1
                if not registered_at and now - started > 90:
                    self.status, self.detail = "no-registration", "never received 001"
                    break
                continue
            except Exception as e:
                self.status = "error"
                self.detail = "%s: %s" % (type(e).__name__, e)
                break

            *lines, buf = buf.split(b"\r\n")
            for raw in lines:
                line = raw.decode("utf-8", "replace")
                if not line:
                    continue
                if line.startswith("PING"):
                    self.send("PONG " + line.split(" ", 1)[1])
                    continue
                # "connected for at least 60 seconds" arrives as a NOTICE on some
                # ircds and as a 421 on others; both mean wait, not refuse.
                m = re.search(r"at least (\d+) second", line, re.I)
                if m and attempts < 3:
                    wait = min(int(m.group(1)) + 5, 180)
                    retry_at = time.time() + wait
                    self.detail = "server requires %ds before LIST" % int(m.group(1))
                elif " NOTICE " in line[:120] and re.search(
                        r"securelist|too heavy|try again", line, re.I):
                    self.detail = self.detail or line.split(":", 2)[-1][:120]
                if line.startswith("ERROR"):
                    self.status = self.status if self.channels else "refused"
                    self.detail = self.detail or line[:160]
                    done = True
                    break

                parts = line.split(" ")
                if len(parts) < 2:
                    continue
                code = parts[1]

                if code == RPL_WELCOME and not registered_at:
                    registered_at = time.time()
                    self.server = parts[0].lstrip(":")
                elif code in (RPL_ENDOFMOTD, ERR_NOMOTD) and not list_sent:
                    request_list()
                    list_sent = True
                    attempts = 1
                elif code == ERR_NICKNAMEINUSE:
                    self.send("NICK rsrch%04d" % random.randint(0, 9999))
                elif code == RPL_LISTSTART:
                    last_row = time.time()
                elif code == RPL_LIST:
                    row = self.parse_list_row(line)
                    if row:
                        self.channels.append(row)
                    last_row = time.time()
                elif code == RPL_LISTEND:
                    # Widely deployed anti-spam modules (InspIRCd's securelist,
                    # solanum's equivalents) answer an early LIST with an empty
                    # list rather than an error: connect, wait ~60s, ask again.
                    if len(self.channels) < 3 and attempts < 2 and \
                            time.time() - started < self.cooldown + 20:
                        retry_at = started + self.cooldown
                        self.detail = "empty first LIST; retrying after %ds cooldown" % self.cooldown
                        continue
                    if not self.channels:
                        self.status = "list-denied"
                        self.detail = self.detail or "LIST returned nothing after %d attempts" % attempts
                    else:
                        self.status = "ok"
                        self.detail = "" if attempts < 2 else "listed only after cooldown"
                    done = True
                    break
                elif code == ERR_UNKNOWNCOMMAND and "LIST" in line and attempts < 3:
                    if not retry_at:
                        retry_at = time.time() + self.cooldown
                        self.detail = self.detail or "LIST refused pending connection age"
                elif code == RPL_TRYAGAIN and not retried:
                    retried = True
                    time.sleep(5)
                    self.send("LIST")
                elif code == ERR_TOOMANYMATCHES and not retried:
                    retried = True
                    self.send("LIST >2")  # ask only for channels with 3+ users
                elif code in FATAL:
                    self.status, self.detail = "refused", FATAL[code]
                    done = True
                    break

        try:
            self.send("QUIT :census complete")
            self.sock.close()
        except Exception:
            pass

        if self.status == "pending":
            self.status = "ok" if self.channels else "no-answer"
        self.elapsed = time.time() - started
        log(self.net, "%s — %d channels in %.0fs %s"
            % (self.status, len(self.channels), self.elapsed,
               ("(%s)" % self.detail) if self.detail else ""))
        return self

    def parse_list_row(self, line):
        """:server 322 nick #channel <users> :<topic>"""
        try:
            rest = line.split(" ", 3)[3]
            name, rest = rest.split(" ", 1)
            users, topic = rest.split(" ", 1)
            if topic.startswith(":"):
                topic = topic[1:]
            # Some ircds prefix modes into the topic field: "[+nt] real topic"
            return {"network": self.net, "channel": name,
                    "users": int(users), "topic": topic.strip()}
        except Exception:
            return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="comma-separated subset of network names")
    ap.add_argument("--timeout", type=int, default=400, help="hard per-network timeout (s)")
    ap.add_argument("--idle", type=int, default=25, help="stop after this many idle seconds mid-LIST")
    ap.add_argument("--cooldown", type=int, default=70,
                    help="seconds to wait before re-asking a network that answered LIST with nothing")
    args = ap.parse_args()

    with open(os.path.join(HERE, "networks.json")) as fh:
        specs = json.load(fh)
    if args.only:
        wanted = set(args.only.split(","))
        specs = [s for s in specs if s["name"] in wanted]

    os.makedirs(RAW, exist_ok=True)
    jobs = [Harvest(s, args.timeout, args.idle, args.cooldown) for s in specs]
    threads = [threading.Thread(target=j.run, daemon=True) for j in jobs]
    t0 = time.time()
    for t in threads:
        t.start()
    for t in threads:
        t.join(args.timeout + 60)

    meta_path = os.path.join(RAW, "_meta.json")
    previous = {}
    if args.only and os.path.exists(meta_path):
        with open(meta_path) as fh:
            old = json.load(fh)
        previous = {n["name"]: n for n in old.get("networks", [])}
    meta = {"collected_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "wall_seconds": round(time.time() - t0, 1),
            "partial_run": bool(args.only),
            "networks": []}
    for j in jobs:
        path = os.path.join(RAW, "%s.jsonl" % j.net)
        with open(path, "w") as fh:
            for c in j.channels:
                fh.write(json.dumps(c, ensure_ascii=False) + "\n")
        meta["networks"].append({
            "name": j.net, "label": j.spec.get("label", j.net),
            "host": j.spec["host"], "port": j.spec["port"],
            "blurb": j.spec.get("blurb", ""), "prior_lang": j.spec.get("prior_lang"),
            "status": j.status, "detail": j.detail, "server": j.server,
            "channels": len(j.channels), "seconds": round(j.elapsed, 1),
        })
    probed = {n["name"] for n in meta["networks"]}
    for name, entry in previous.items():
        if name not in probed:
            meta["networks"].append(entry)
    meta["networks"].sort(key=lambda n: -n["channels"])
    with open(meta_path, "w") as fh:
        json.dump(meta, fh, indent=2, ensure_ascii=False)

    ok = sum(1 for n in meta["networks"] if n["status"] in ("ok", "partial"))
    print("\n%d/%d networks in the frame have channel data (this run probed %d, %.0fs)"
          % (ok, len(meta["networks"]), len(jobs), meta["wall_seconds"]))


if __name__ == "__main__":
    main()
