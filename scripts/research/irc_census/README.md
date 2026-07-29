# IRC public network census

Answers one question with primary data instead of folklore: **who still uses IRC
in 2026, in what language, about what?**

Every surviving IRC network answers `/LIST` — the standard command that returns
each publicly listed channel with its member count and topic. This tool asks all
of them at once, classifies the answers, and prints a report.

## Run it

```bash
scripts/research/irc_census/run.sh                    # collect + report
scripts/research/irc_census/run.sh --refresh-frame    # re-derive the target list first
scripts/research/irc_census/run.sh --only libera,rizon
scripts/research/irc_census/run.sh --report-only      # re-render from last harvest
```

Python 3 stdlib only — no venv, no packages. A full sweep takes a few minutes;
networks are probed concurrently, one thread each.

## Pieces

| File | Responsibility |
|------|----------------|
| `discover.py` | derives the target list from a public directory — **addresses only** |
| `networks.json` | the survey frame it produces: which networks, and where |
| `annotations.json` | hand-written colour: language prior and one-line character |
| `collect.py` | one anonymous `/LIST` session per network → `data/raw/*.jsonl` |
| `classify.py` | language and subject heuristics, each verdict carrying its evidence |
| `report.py` | the ten sections of `data/report.txt` |

**The web is an address book here, nothing more.** `discover.py` reads hostnames,
ports and TLS flags from netsplit.de's public directory because a hand-curated
list silently omits whatever the author never heard of — in the first pass that
meant the Bulgarian, Turkish, Malay and Brazilian networks. No user count, no
channel count and no ranking from any directory reaches the report. Every number
in `data/report.txt` comes from a live `/LIST` against the server itself.

Outputs land in `data/` and are gitignored — the report is a snapshot of a live
network, so it is meant to be regenerated, not committed.

## What the client does

Connects, registers a throwaway nick, sends `LIST`, reads the reply, quits. It
joins nothing, says nothing, and reads no conversation. Everything it collects is
what any IRC client shows in its channel browser.

## Reading the numbers honestly

- **Occupancy is not population.** Summing per-channel member counts counts a
  user once per channel they sit in. It measures where attention is pointed, not
  how many people exist. Networks publish unique user counts separately.
- **`LIST` is a floor.** Channels set `+s`/`+p` are invisible to it, and some
  networks hide small channels by default. Nothing here is a total.
- **Language and subject are heuristics.** `classify.py` prefers writing system,
  then diacritics, then stopwords, then channel-name tokens, then the network's
  prior. Every classified row in `data/channels.jsonl` carries a `lang_evidence`
  and `subject_evidence` field, so any bucket can be audited or contested.
- **`und` is missing data, not a language.** It marks a channel that offered no
  signal, usually an English-looking name with an empty topic.

## Networks that answer with nothing

Several networks run anti-spam modules (InspIRCd's `securelist` and its cousins)
that answer a `LIST` sent in the first minute after connecting with an *empty
list* rather than an error — indistinguishable from a dead network if you take it
at face value. `collect.py` treats a first empty answer as a cooldown signal,
waits `--cooldown` seconds and asks once more; `data/raw/_meta.json` records which
networks only listed on the second ask.

Others refuse outright: a datacenter IP lands on Spamhaus lists, and networks like
euIRC and EpiKnet k-line the connection on sight. Those show as `refused` with the
server's own words. They are reported as missing, never as empty.

## Adding a network

`discover.py` regenerates `networks.json`, so hand-edits there are transient. To
give a network a language prior or a character note, add it to `annotations.json`
under its directory label — that file survives regeneration. The blurb is not
decoration: it appears in the report as the qualitative column beside the counts.
