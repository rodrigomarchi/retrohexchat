# Documentation Index

Living documentation for retro_hex_chat. `AGENT-GUIDE.md` holds the durable rules,
`reference/` holds the inventories that must track the code, and `plans/` holds work
that is currently in flight — a plan is deleted once its work ships, with any durable
rule moved into the guide first.

## Guide

- [AGENT-GUIDE.md](AGENT-GUIDE.md) — the durable engineering guide: the 11 governing
  principles plus hard-won rules (state tiers, command/dispatch, LiveComponent island
  decomposition, WebRTC/P2P and call recovery, windowed desktop, background jobs (Oban),
  mobile/touch, JS hook loading standard, i18n/public URLs, testing gotchas). Start here.

## Reference

Living catalogs and runbooks kept current with the code:

- [reference/i18n-catalogs.md](reference/i18n-catalogs.md) — Gettext catalog conventions,
  the locale roster, and rollout waves (`config/i18n_locales.exs`).
- [reference/conferencia-canal-permissoes.md](reference/conferencia-canal-permissoes.md) —
  the authority matrix for channel conferences: the call inherits the channel hierarchy,
  there is no separate host/moderator role.
- [reference/media-session-p2p-conference-current.md](reference/media-session-p2p-conference-current.md)
  — the current surfaces and sections of the unified P2P/conference media session.
- [reference/call-handshake-resilience-map.md](reference/call-handshake-resilience-map.md) —
  which files take part in each handshake/recovery path, and what the tests already cover.
  The rules themselves are AGENT-GUIDE §8.5.
- [operations/group-call-sfu.md](operations/group-call-sfu.md) — runtime env vars and
  operational notes for the embedded group-call SFU.

Runbooks live next to what they run, not here:

- [`scripts/server-provision.md`](../scripts/server-provision.md) — the production provisioning
  script pasted into the Admin Console, plus the IRC census behind the channel choices.

There is deliberately **no icon inventory**: `components/icons/` and `/showcase/icons` are the
catalog, because a hand-written list of 344 icons is stale on arrival.

## Conventions

- Add a durable, cross-cutting engineering learning → `AGENT-GUIDE.md`.
- Add a living inventory that must track the code → `reference/`, and link it here. If the code
  can answer the question directly (grep a module, open `/showcase/icons`), do not write the
  inventory at all.
- Runbooks and scripts document themselves in place, beside the thing they operate.
- Starting a big piece of work? Write the plan in `plans/` and keep it there while the work is
  open. `plans/` is empty right now only because nothing is in flight.
- Finished a plan? Extract any durable rule into `AGENT-GUIDE.md`, then delete the plan. A plan
  that outlives its work stops describing the codebase and starts misdescribing it — two of the
  ones removed here still claimed a phase was open for features that had shipped weeks earlier.
</content>
