# Provisioning scripts

One script per language the server speaks. Each is a document that is also a
program: an operator pastes its fenced block into the Admin Console and the
console runs it line by line.

**[`en.md`](en.md) runs first.** It is the base script — the only one that sets
the server's name, description and welcome message — and the twelve English
rooms it opens are the ones every other script assumes already exist. The rest
add rooms on top and can be pasted in any order, or not at all.

| script | rooms | bots | feeds | social room |
|---|---|---|---|---|
| [`en.md`](en.md) | 12 | 21 | 47 | `#lobby` |
| [`pt_BR.md`](pt_BR.md) | 10 | 12 | 23 | `#brasil` |
| [`pt_PT.md`](pt_PT.md) | 10 | 12 | 18 | `#portugal` |
| [`es.md`](es.md) | 12 | 14 | 25 | `#hispano` |
| [`fr.md`](fr.md) | 11 | 13 | 25 | `#france` |
| [`de.md`](de.md) | 10 | 12 | 20 | `#deutschland` |
| [`it.md`](it.md) | 10 | 12 | 19 | `#italia` |
| [`nl.md`](nl.md) | 10 | 12 | 21 | `#nederland` |
| [`pl.md`](pl.md) | 10 | 12 | 23 | `#polska` |
| [`ru.md`](ru.md) | 10 | 12 | 21 | `#russkiy` |
| [`id.md`](id.md) | 10 | 12 | 29 | `#indonesia` |
| [`ja.md`](ja.md) | 10 | 12 | 22 | `#nihon` |
| [`zh_hans.md`](zh_hans.md) | 10 | 12 | 20 | `#zhongwen` |
| [`zh_hant.md`](zh_hant.md) | 10 | 12 | 21 | `#fanti` |

The file names are the locale codes from
[`config/i18n_locales.exs`](../../config/i18n_locales.exs), which is the single
source of truth for the supported set. A locale added there needs a script here:
`server_provision_test.exs` fails until the two agree.

## The rules every script follows

These are not style preferences. Each one is enforced by
`apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/server_provision_test.exs`,
which lints all fourteen files against the handlers that have to run them.

- **English prose, native rooms.** The documentation around a script is written
  for whoever pastes it; every line a user reads — topics, greetings, bot answers
  — is in that script's language.
- **Only `en.md` touches server-wide settings.** Otherwise the server would be
  renamed by whichever language was pasted last.
- **Channel and bot names are unique across the whole directory.** They share one
  server: `#nauka` could only belong to Polish, so Russian took `#nauchpop`.
- **Channel names are ASCII.** `chat_helpers.ex` only turns `[a-zA-Z][a-zA-Z0-9_-]*`
  into a link, so `#wiadomości` would be a room nobody could click. Bot
  nicknames are ASCII too, because the schema demands it. Nothing else is
  restricted — topics and speech are written properly, in whatever script the
  language uses.
- **Every room has a feed.** A room with three people and nothing happening is
  dead; a room with three people and a wire has something on it every hour.
- **One moderator per language, in every room, silent.** A warning nobody can
  read is not a warning, which is why the English `Brutus` does not cover the
  other thirteen. A bot in every room that also greets would double every
  welcome.
- **Exactly one greeter per room.** A welcome has two halves and both belong to
  the same bot: `public_greeting` is one short line the room sees, and it is sent
  **only the first time that bot meets that name there**; `greeting` and the
  `onboarding_*` lines are private notices to the newcomer alone. Splitting the
  halves across two bots would announce everybody twice.
- **The IRC half of a welcome is the same in every room of a script.**
  `onboarding_1` and `onboarding_2` teach `/join`, `/msg`, `/nick`, tabs and
  `/help` — the same thing whichever door somebody comes through. They are
  written once per language and repeated verbatim per room, which is a
  duplication the lint checks rather than tolerates.
- **No farewells.** They become noise on reconnect churn.
- **A bot only advertises triggers it answers.** `!fontes` in a greeting from a
  bot with no `fontes` command promises silence, and the promise reads as a bug
  in the room rather than in the script.

## Feeds

**Every feed in every script was fetched by the production fetcher and decoded by
the production parser before it was written down.** 471
candidates were tried and 289 survived; the rest returned 404, 403, oversized
bodies, or RDF 1.0, which the parser does not read — that last one cost Japan
four of its best-known sources.

Re-check any address the same way:

```bash
mix run scripts/research/rss_probe.exs candidates.txt   # one URL per line
```

It prints `OK` / `EMPTY` / `PARSE` / `DEAD` per line, so a feed that has gone
quiet or moved shows up before an operator pastes it.

Poll intervals follow the publisher rather than a house default: twenty minutes
for a newsroom, two hours for a blog that posts twice a week. Both the feed list
and the record of what has been seen live on the bot, so a deploy does not
replay the day.

## Cadence

Flood protection runs in each reader's session: a nickname that sends more than
`flood_threshold` messages inside `flood_window_seconds` is auto-ignored by that
reader for five minutes. Nothing on the server stops it and nothing tells the
bot, so a wire bot that delivered a feed page in one burst simply went quiet for
whoever was counting — which is what happened to `Vasco` and `Nina`.

So a poll announces a batch, not a page. What does not fit is **not discarded**:
it stays unseen and a feed holding a backlog is polled again in under a minute
instead of waiting out its interval. A hundred-item first read still arrives in
full, spread over minutes, in the order it was published.

The pace itself is derived from the flood settings at half the rate that would
trigger them, keyed by **nickname** — a bot with five feeds on one interval
polls them together, and five polite feeds still add up to one impolite bot.

Scripts therefore do not set `rss_max_items`; the default tracks the flood
budget. [`cadence-migration.txt`](cadence-migration.txt) carries the one-time
`/bot set` block for bots provisioned before this existed, which still hold the
old ceiling of 10,000.

## Applying a change to a server that is already running

A script here opens a server that does not exist yet: it creates bots and puts
them in rooms. A live server needs the same change with none of that — the
`/bot set` lines alone, pasted once into the Admin Console.

Derive that block from the scripts rather than keeping a copy of it. The scripts
are the source of truth, a copy goes stale the moment one of them is edited, and
the block is worth nothing the day after it is pasted:

```bash
for f in docs/provisioning/*.md; do
  locale=$(basename "$f" .md); [ "$locale" = README ] && continue
  echo "# ── $locale ──"
  grep -E '^/bot set [A-Za-z]+ (public_greeting|onboarding_[1-4]) ' "$f"
done
```

Swap the key names for whichever settings the change touches. Each bot's lines
are adjacent in its script, so the output comes out grouped by bot already.

**Deploy first.** A key that the running release does not know comes back as an
unknown setting, and the paste is silently half-applied.

[`cadence-migration.txt`](cadence-migration.txt) is the one block kept as a file:
it lowers a ceiling that no script sets any more, so there is nothing left to
derive it from.

## Adding a language

1. Add the locale to `config/i18n_locales.exs` (see [`.claude/rules/i18n.md`](../../.claude/rules/i18n.md)).
2. Collect candidate feeds, probe them, keep what parses.
3. Write `<code>.md` next to these, following the rules above.
4. Run the lint — it will tell you what you got wrong before anyone pastes it:

```bash
mix test apps/retro_hex_chat/test/retro_hex_chat/commands/handlers/server_provision_test.exs
```

The Playwright spec `e2e/tests/chat-admin-server-provision.spec.ts` executes
`en.md` end to end against a real console. It is the only thing that proves a
script works rather than merely parses; it is local-only and not part of
`make ci`.
