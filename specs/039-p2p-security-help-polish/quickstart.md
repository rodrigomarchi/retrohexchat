# Quickstart: P2P Security, Help & Polish

**Feature**: 039-p2p-security-help-polish
**Date**: 2026-02-16

## Prerequisites

- Existing P2P stack fully functional (features 034-038)
- PostgreSQL running with existing schema (no migrations needed)
- TURN server configuration in `config/runtime.exs` (already present)

## Key Files to Modify

### Elixir (Domain — `apps/retro_hex_chat/`)

| File | Change |
|------|--------|
| `lib/retro_hex_chat/p2p/rate_limiter.ex` | **NEW** — Sliding-window rate limiter for session creation |
| `lib/retro_hex_chat/p2p/signaling_rate_limit/ets.ex` | **NEW** — ETS-based SignalingRateLimit behaviour impl |
| `lib/retro_hex_chat/p2p/service.ex` | Add rate limit check before session creation |
| `lib/retro_hex_chat/p2p/policy.ex` | Update error message for blocked users |
| `lib/retro_hex_chat/p2p/p2p.ex` | Add `turn_configured?/0`, `close_sessions_between/2` delegates |
| `lib/retro_hex_chat/p2p/supervisor.ex` | Init ETS table for rate limits |
| `lib/retro_hex_chat/chat/help_topics/features.ex` | Add 4 P2P help topics |
| `lib/retro_hex_chat/chat/help_topics/keyboard_shortcuts.ex` | Update with P2P shortcuts |
| `config/config.exs` | Update `signaling_rate_limiter` default, add `p2p_session_rate_limit` |

### Elixir (Web — `apps/retro_hex_chat_web/`)

| File | Change |
|------|--------|
| `lib/retro_hex_chat_web/live/p2p_session_live.ex` | Add privacy mode assign, toggle event, pass `turn_only` to ICE events |
| `lib/retro_hex_chat_web/components/p2p_lobby.ex` | Add "Modo privado" checkbox, TURN warning |

### JavaScript (`apps/retro_hex_chat_web/assets/`)

| File | Change |
|------|--------|
| `js/lib/webrtc.js` | Add `options` param to `createPeerConnection` for `iceTransportPolicy` |
| `js/hooks/webrtc_hook.js` | Pass `turn_only` flag from LiveView event to `createPeerConnection` |

### Tests

| File | Purpose |
|------|---------|
| `test/retro_hex_chat/p2p/rate_limiter_test.exs` | **NEW** — Unit tests for rate limiter |
| `test/retro_hex_chat/p2p/signaling_rate_limit/ets_test.exs` | **NEW** — Unit tests for signaling rate limit |
| `test/retro_hex_chat/p2p/service_test.exs` | Add rate limit integration tests |
| `test/retro_hex_chat/p2p/policy_test.exs` | Update error message assertions |
| `test/retro_hex_chat/chat/help_topics_test.exs` | Add tests for new topics |
| `test/retro_hex_chat_web/live/p2p_session_live_test.exs` | Privacy mode toggle, rate limit errors |
| `assets/test/lib/webrtc.test.js` | Privacy mode ICE transport policy test |

### Config

| File | Change |
|------|--------|
| `config/config.exs` | `signaling_rate_limiter: RetroHexChat.P2P.SignalingRateLimit.ETS` |
| `config/config.exs` | `p2p_session_rate_limit: {5, 600_000}` |
| `config/config.exs` | `turn_credentials_lifetime: 3_600` (reduce from 86_400 to match spec) |
| `config/test.exs` | Override rate limits for test speed |

## Implementation Order

1. **Rate Limiter** (P1) — `RateLimiter` module + ETS SignalingRateLimit + wire into Service
2. **Privacy Mode** (P2) — Preference read/write + `webrtc.js` transport policy + lobby checkbox
3. **Ignore Integration** (P2) — Update error messages + active session closure on block
4. **Help Topics** (P3) — 4 new topics + keyboard shortcuts update
5. **Config tweaks** — Credential TTL, rate limiter defaults

## Validation

Run full CI pipeline per CLAUDE.md:
1. `mix compile --warnings-as-errors`
2. In parallel: `mix format --check-formatted`, `mix credo --strict`, `make lint.js`, `make lint.css`, `npm test --prefix apps/retro_hex_chat_web/assets`, `mix test --include e2e`, `mix dialyzer`
