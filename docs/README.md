# Documentation Index

Living documentation for retro_hex_chat. `AGENTS.md` at the repository root is the
entry point and carries the always-true rules; everything here loads on demand.
`AGENT-GUIDE.md` holds the durable engineering constitution, `guide/` holds the
per-subsystem playbooks, `reference/` holds the inventories that must track the
code, and `plans/` holds work that is currently in flight — a plan is deleted once
its work ships, with any durable rule moved into the guide first.

The **Read when** column is the point of this table. Do not read a row whose
trigger has not fired.

## Guide

- [AGENT-GUIDE.md](AGENT-GUIDE.md) — the durable engineering guide: the governing
  principles plus hard-won rules (state tiers, command/dispatch, PubSub & permissions,
  persistence, UI composition, CSS/SVG, mIRC parity, help, process discipline, JS hook
  loading standard, i18n/public URLs). **Start here for any non-trivial change.**

### Subsystem playbooks (`guide/`)

Long-form knowledge for one area, split out of the guide so reading about one
subsystem does not pull in the other five. Section numbers are stable: `§6` still
means island decomposition wherever it lives.

| File | Read when |
|---|---|
| [guide/liveview-islands.md](guide/liveview-islands.md) (§6) | Extracting, editing or debugging a LiveComponent island — ownership, event routing, `send_update` timing, streams, bubbling, modals, async work |
| [guide/windowed-desktop.md](guide/windowed-desktop.md) (§7) | Adding or changing a window, dialog, taskbar entry or Start menu item |
| [guide/webrtc-p2p.md](guide/webrtc-p2p.md) (§8) | Calls, signaling, TURN, file transfer, call recovery |
| [guide/testing.md](guide/testing.md) (§13) | Writing or debugging tests — the flaky-suite rules and what to assert on |
| [guide/background-jobs.md](guide/background-jobs.md) (§17) | Oban workers, queues, recurrence, observability |
| [guide/mobile-touch.md](guide/mobile-touch.md) (§18) | Viewport contract, touch handling, mobile dialog patterns |
| [guide/surfaces.md](guide/surfaces.md) (§19) | A screen with an address of its own: how one is entered, the share-link resolver, which tabs a person has open |

## Reference

Living catalogs and runbooks kept current with the code:

| File | Read when |
|---|---|
| [reference/ci-pipeline.md](reference/ci-pipeline.md) | A CI check fails, tuning partitions, adding a check, browser E2E, deploy mechanics |
| [reference/i18n-catalogs.md](reference/i18n-catalogs.md) | Gettext catalog conventions, the locale roster, and rollout waves (`config/i18n_locales.exs`) |
| [reference/conferencia-canal-permissoes.md](reference/conferencia-canal-permissoes.md) | The authority matrix for channel conferences: the call inherits the channel hierarchy, there is no separate host/moderator role |
| [reference/media-session-p2p-conference-current.md](reference/media-session-p2p-conference-current.md) | The current surfaces and sections of the unified P2P/conference media session |
| [reference/call-handshake-resilience-map.md](reference/call-handshake-resilience-map.md) | Which files take part in each handshake/recovery path, and what the tests already cover. The rules themselves are [`guide/webrtc-p2p.md` §8.5](guide/webrtc-p2p.md) |
| [operations/group-call-sfu.md](operations/group-call-sfu.md) | Runtime env vars and operational notes for the embedded group-call SFU |

Runbooks live next to what they run, not here:

- [`provisioning/`](provisioning/README.md) — the provisioning scripts pasted into the Admin
  Console, one per language the server speaks. `en.md` runs first and carries the IRC census
  behind the channel choices; the rest add rooms in their own language.
- [`e2e/README.md`](../e2e/README.md) — the Playwright suite, intentionally outside `make ci`.
  Each spec documents its own flows in an `@flow` header; `e2e/TEST_CATALOG.md` is the
  generated index, and `make ci` fails if the two drift apart.
- [`virtual.space/`](../virtual.space/) — the PixelLab art pipeline (scenes, characters,
  animations, isometric). Surfaced to Claude Code as the `virtual-space-art` skill.

There is deliberately **no icon inventory**: `components/icons/` and `/showcase/icons` are the
catalog, because a hand-written list of icons is stale on arrival. The same applies to
migration, context, schema and hook counts — never write them into prose.

## In flight (`plans/`)

- [plans/retro-games-ai.md](plans/retro-games-ai.md) — nova superfície `Retro Games`
  para jogos nativos do chat em modo single player contra AI, começando pelo Hex Pong.
The channel/PM unification shipped and its plan was deleted; the rule it produced
is Principle 12 in `AGENT-GUIDE.md`.

The shareable-surfaces plans are deleted, as they instructed. What they produced
lives where the code is: the surface rules in
[`guide/surfaces.md`](guide/surfaces.md) §19, the readiness protocol and the
`phx-update="ignore"` rule in `AGENT-GUIDE.md` §15, the testing gotchas in
[`guide/testing.md`](guide/testing.md), and the two decisions that were argued and
refused — a readable space address, and a rate limit that belongs at the edge — in
the `@moduledoc` of the modules they govern. The i18n debt they measured but did
not clear is in
[`reference/i18n-catalogs.md`](reference/i18n-catalogs.md).

`plans/` holds work in flight and nothing else. A finished plan's durable rules
move into `AGENT-GUIDE.md` or a `guide/` playbook and the plan is deleted — a
record of how something came to be is not a thing anybody needs to read to
change it.

## Conventions

- Add a durable, cross-cutting engineering learning → `AGENT-GUIDE.md`.
- Add long-form knowledge about one subsystem → `guide/`, and link it above with a
  **Read when** trigger. A playbook nobody knows to open is a playbook nobody reads.
- Add a living inventory that must track the code → `reference/`, and link it here. If the code
  can answer the question directly (grep a module, open `/showcase/icons`), do not write the
  inventory at all.
- Add a rule that only applies to part of the tree → `.claude/rules/` with a `paths:`
  glob, so it loads exactly when it is relevant instead of in every session.
- Add a rule that a tool can check → make the tool check it. A linter, a hook or a CI
  check beats a paragraph asking the agent to remember.
- Runbooks and scripts document themselves in place, beside the thing they operate.
- Starting a big piece of work? Write the plan in `plans/` and keep it there while the work is
  open.
- Finished a plan? Extract any durable rule into `AGENT-GUIDE.md`, then delete the plan. A plan
  that outlives its work stops describing the codebase and starts misdescribing it — two of the
  ones removed here still claimed a phase was open for features that had shipped weeks earlier.
