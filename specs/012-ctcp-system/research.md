# Research: CTCP (Client-to-Client Protocol)

**Feature**: 012-ctcp-system
**Date**: 2026-02-12

## Research Topics

### 1. CTCP Request/Reply Delivery via PubSub

**Decision**: Use existing `user:#{nickname}` PubSub topic with tuple messages `{:ctcp_request, payload}` and `{:ctcp_reply, payload}`.

**Rationale**: This is the established pattern used by notices (`{:new_notice, payload}`), PM notifications, and channel invites. No new PubSub topics needed. Each LiveView process subscribes to its own `user:#{nickname}` topic on mount, so CTCP messages are automatically routed to the correct process.

**Alternatives considered**:
- Dedicated `ctcp:#{nickname}` topic: Rejected — adds unnecessary topic proliferation. The `user:` topic already handles per-user messaging.
- Direct PID-based messaging: Rejected — PubSub is the established pattern and works across nodes.

### 2. CTCP Timeout Mechanism

**Decision**: Use `Process.send_after(self(), {:ctcp_timeout, request_id}, 10_000)` in the sender's LiveView process. Store the timer reference in socket assigns to enable cancellation on reply receipt.

**Rationale**: This is the same pattern used for channel invite expiration (5-minute timer) and notify debounce (10-second timer) in the existing codebase. It's simple, reliable, and doesn't require external dependencies.

**Alternatives considered**:
- GenServer-based timeout manager: Rejected — over-engineering for ephemeral per-process timers.
- `:timer` module: Rejected — Process.send_after is more idiomatic in LiveView.

### 3. CTCP Rate Limiting Approach

**Decision**: Socket assigns-based rate limiting using a map of `%{downcased_target => [monotonic_timestamps]}`. On each send, prune timestamps older than 30 seconds and check if remaining count < 3.

**Rationale**: CTCP rate limiting is per-sender-target pair. Since the sender is always the current LiveView process, socket assigns are the natural storage. No shared state needed. Simple to implement and test.

**Alternatives considered**:
- ETS-based `RateLimit.Limiter`: Rejected — the existing limiter is per-user (not per-user-pair) and uses token bucket semantics. CTCP needs a simpler sliding window per target. Modifying the shared limiter adds complexity for a feature-specific need.
- GenServer-based rate tracker: Rejected — unnecessary process overhead for per-connection state.

### 4. PING Latency Measurement

**Decision**: Use `System.monotonic_time(:millisecond)` for sent_at timestamp. Calculate latency as `System.monotonic_time(:millisecond) - sent_at` on reply receipt.

**Rationale**: Monotonic time is immune to system clock adjustments and provides accurate elapsed time measurement. This measures the PubSub round-trip time within the application, which is the meaningful "latency" in a simulated CTCP context.

**Alternatives considered**:
- `DateTime.utc_now()` with `DateTime.diff/3`: Rejected — wall clock time can jump due to NTP adjustments. Less precise for short-duration measurements.
- `:os.system_time(:millisecond)`: Acceptable but `System.monotonic_time` is more semantically correct for elapsed time.

### 5. Idle Time for FINGER Default

**Decision**: Add `last_message_at` field to Session struct (DateTime, default `DateTime.utc_now()` on session creation). Update on every sent message. FINGER idle time = `DateTime.diff(DateTime.utc_now(), last_message_at, :second)`.

**Rationale**: Simple and accurate. The Session struct is already modified on every message send (for message history, etc.), so adding a timestamp update is trivial. Using seconds is sufficient granularity for "idle 5 minutes" display.

**Alternatives considered**:
- Presence-based idle tracking: Rejected — Presence tracks online/away status, not message activity timestamps.
- ETS-based activity tracker: Rejected — the Session struct is the right place for per-user state.

### 6. CTCP Settings Storage Model

**Decision**: Single `ctcp_settings` table with columns: `owner_nickname` (PK, FK to registered_nicks), `enabled` (boolean, default true), `version_string` (string, default "RetroHexChat v1.0"), `finger_text` (string, nullable). In-memory representation as a map in Session struct.

**Rationale**: Matches the notice_routing_settings pattern exactly. Single row per user with upsert on save. Simple and proven.

**Alternatives considered**:
- JSON column: Rejected — individual columns are simpler to validate and migrate.
- Separate table per setting type: Rejected — unnecessary normalization for 3 settings.

### 7. Self-CTCP Handling

**Decision**: Handle self-CTCP entirely within the sender's LiveView process. No PubSub broadcast needed. Generate the reply immediately using the sender's own session settings. PING returns 0ms.

**Rationale**: Self-CTCP is a shortcut — no network round-trip, no timeout, no rate limiting needed. It's useful for testing and should feel instant.

**Alternatives considered**:
- Send via PubSub to self: Rejected — unnecessary round-trip that would add non-zero latency to a "0ms" response.
