# Research: RetroHexChat Phase 1

**Date**: 2026-02-09
**Spec**: [spec.md](./spec.md)

All technology decisions were provided upfront by the user. No NEEDS
CLARIFICATION items exist. This document records the rationale for each
decision.

---

## 1. Elixir & OTP Versions

**Decision**: Elixir 1.17+ / OTP 27+
**Rationale**: Latest stable versions. OTP 27 brings performance
improvements to the BEAM scheduler and process management, directly
benefiting a process-per-channel architecture. Elixir 1.17 includes
improvements to pattern matching and compile-time checks.
**Alternatives considered**: Elixir 1.16 / OTP 26 (still supported, but
no reason to use older versions for a greenfield project).

## 2. Phoenix & LiveView Versions

**Decision**: Phoenix 1.7+ with LiveView 1.0+
**Rationale**: Phoenix 1.7 introduced verified routes, the unified
component system, and first-class LiveView integration. LiveView 1.0+
provides stable streams API (critical for chat message rendering) and
mature lifecycle hooks.
**Alternatives considered**: None — Phoenix is the only Elixir web
framework that meets our constitution.

## 3. Database & ORM

**Decision**: PostgreSQL 16+ with Ecto
**Rationale**: PostgreSQL 16 adds performance improvements for large
datasets and better parallelism. Ecto is the standard Elixir data mapper
with excellent migration tooling, schema validation, and query
composition. Cursor-based pagination via timestamps avoids the O(n)
offset problem. GIN/trigram indexes enable efficient text search without
external search services.
**Alternatives considered**: PostgreSQL 15 (viable but 16 is preferred
for its improvements).

## 4. Cursor-Based Pagination Strategy

**Decision**: Use `inserted_at` timestamps as cursors with composite
index on `(channel_name, inserted_at)`. Query pattern:
`WHERE channel = ? AND inserted_at < ? ORDER BY inserted_at DESC LIMIT 50`.
**Rationale**: Timestamps provide natural ordering for chat messages.
Composite indexes make range scans efficient even with millions of rows.
No offset means consistent performance regardless of page depth.
**Alternatives considered**: UUID-based cursors (rejected — UUIDs don't
sort chronologically without UUIDv7), offset pagination (rejected — O(n)
for deep pages).

## 5. Text Search Strategy

**Decision**: PostgreSQL trigram index (pg_trgm extension) with
`ILIKE` or `similarity()` for chat search. GIN index on message content.
**Rationale**: Trigram indexes support partial string matching and are
efficient for the "find text in messages" use case. No external search
engine needed for Phase 1 scale (100k messages per channel). PostgreSQL
full-text search (tsvector) is an alternative but trigrams are better for
substring/partial matching which is what Ctrl+F search expects.
**Alternatives considered**: PostgreSQL full-text search (tsvector —
good for keyword search but not for substring matching), Elasticsearch
(overkill for Phase 1 scale).

## 6. Password Hashing

**Decision**: bcrypt via `bcrypt_elixir`
**Rationale**: Elixir ecosystem standard (used by phx.gen.auth). Well-
tested, secure, and broadly understood. Test configuration uses reduced
rounds (log_rounds: 4) for fast test execution.
**Alternatives considered**: Argon2 via `argon2_elixir` (technically
superior for GPU resistance, but adds NIF complexity with less ecosystem
precedent).

## 7. Asset Bundling

**Decision**: esbuild (Phoenix default)
**Rationale**: Zero-config with Phoenix 1.7+. Fast builds. Supports
importing retro design system from node_modules. No need for Webpack/Vite complexity.
**Alternatives considered**: Webpack (unnecessary complexity), Vite
(overkill for CSS + minimal JS hooks).

## 8. retro design system Integration

**Decision**: Install via npm, import in Phoenix assets pipeline
**Rationale**: retro design system is a pure CSS library with no JS dependencies.
Install via npm for versioning, import in `app.css`. Dark theme
implemented as a separate CSS file with custom properties overriding
retro design system defaults.
**Alternatives considered**: CDN (rejected — no offline support, version
pinning issues), copy-paste (rejected — no update path).

## 9. Rate Limiting Strategy

**Decision**: ETS-based token bucket in `RetroHexChat.RateLimit` context.
5 msg/sec for messages, 2 cmd/sec for commands. Temporary mute (2-3
seconds) on violation.
**Rationale**: ETS provides atomic operations and shared state without
GenServer bottleneck. Token bucket is simple, well-understood, and
handles burst patterns naturally. In-memory only — no DB persistence
needed for transient rate state.
**Alternatives considered**: GenServer-per-user (unnecessary process
overhead), external rate limiter like Hammer (dependency for a simple
use case).

## 10. Session & Disconnect Handling

**Decision**: Immediate disconnect on socket close. No grace period.
**Rationale**: Simplifies implementation significantly. LiveView's
`terminate/2` callback handles cleanup. Nickname immediately available.
Ghost sessions handled by NickServ `/ns ghost` command for edge cases.
**Alternatives considered**: 30-second grace period (adds complexity
with timers and "reconnecting" state management — deferred to future).

## 11. PubSub Topic Convention

**Decision**: Structured topic strings —
- `"channel:#{name}"` for channel events
- `"pm:#{sorted_nicks}"` for private messages (nicknames sorted
  alphabetically, joined with `:`, e.g., `"pm:Admin:Rodrigo"`)
- `"user:#{nickname}"` for user-scoped events (nick changes, away)
- `"service:nickserv"` / `"service:chanserv"` for service messages
**Rationale**: Consistent naming prevents subscription bugs. Sorted
nicknames for PM topics ensure bidirectional conversations use one topic.
Phase 1 has no persistent user IDs, so nicknames are the only viable key.
**Nick change impact on PM topics**: When a user changes nickname, the
LiveView unsubscribes from old PM topics and resubscribes with the new
nickname. DB records retain the nickname at time of send (immutable).
Conversation history queries use both old and new nicknames.
**Alternatives considered**: Separate topics per PM direction (rejected
— doubles subscriptions), session-ID-based topics (rejected — session
IDs are not meaningful to users and complicate debugging).

## 12. Observability (Deferred from Clarification)

**Decision**: Lightweight Telemetry events for key domain actions.
Emit `[:retro_hex_chat, :message, :sent]`,
`[:retro_hex_chat, :user, :connected]`,
`[:retro_hex_chat, :channel, :created]`,
`[:retro_hex_chat, :command, :executed]`. No metrics backend in Phase 1.
**Rationale**: Elixir Telemetry is zero-cost when no handler is attached.
Instrumenting from day one means metrics backends can be wired later
without code changes. Phoenix already emits Telemetry for HTTP/socket
events.
**Alternatives considered**: No telemetry (rejected — goes against
constitution VIII), full metrics stack (overkill for Phase 1).
