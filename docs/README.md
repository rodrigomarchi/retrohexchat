# Documentation Index

Living documentation for retro_hex_chat. Plan/progress files are intentionally
**not** kept here — their durable learnings are crystallized into `AGENT-GUIDE.md`
once implemented, and the plans themselves are removed as noise.

## Guide

- [AGENT-GUIDE.md](AGENT-GUIDE.md) — the durable engineering guide: the 11 governing
  principles plus hard-won rules (state tiers, command/dispatch, LiveComponent island
  decomposition, WebRTC/P2P and call recovery, windowed desktop, background jobs (Oban),
  mobile/touch, JS hook loading standard, i18n/public URLs, testing gotchas). Start here.

## Reference

Living catalogs and runbooks kept current with the code:

- [reference/i18n-catalogs.md](reference/i18n-catalogs.md) — Gettext catalog conventions,
  the locale roster, and rollout waves (`config/i18n_locales.exs`).
- [reference/server-provision.md](reference/server-provision.md) — production provisioning
  runbook: the Admin Console script that seeds channels, bots, and server settings.
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

There is deliberately **no icon inventory** here: `components/icons/` and `/showcase/icons`
are the catalog, because a hand-written list of 344 icons is stale on arrival.

## Plans

`plans/` holds only work that is **still in flight**. A plan there means the work is open;
if you finish it, the plan leaves with it.

## Conventions

- Add a durable, cross-cutting engineering learning → `AGENT-GUIDE.md`.
- Add a living inventory/runbook → `reference/`, and link it here.
- Finished a plan? Extract any durable learning into `AGENT-GUIDE.md`, then delete the plan —
  implemented plans with no residual learning are just noise.
</content>
