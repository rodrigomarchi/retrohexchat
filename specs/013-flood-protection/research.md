# Research: Flood Protection (013)

**Feature**: 013-flood-protection
**Date**: 2026-02-12

## R1: Flood Tracking Strategy — In-Process vs. Shared State

**Decision**: In-process tracking via socket assigns (per-LiveView-process state).

**Rationale**: The existing project already uses this pattern for CTCP rate limiting (`ctcp_rate_limits` in socket assigns). Flood protection is a per-user concern — each user independently decides what constitutes flooding based on their own thresholds. Socket assigns are the natural fit: zero coordination overhead, automatic cleanup on disconnect, no shared mutable state.

**Alternatives considered**:
- **ETS table (shared)**: Would allow server-wide flood detection but contradicts the spec requirement that flood protection is per-user. Would also introduce coordination complexity and require cleanup logic. The existing `RateLimit.Limiter` uses ETS for server-enforced rate limiting, which is a different concern (global enforcement vs. user-configurable filtering).
- **GenServer per user**: Unnecessary overhead — LiveView processes already provide per-user state isolation. Adding a GenServer would duplicate state management without benefit.

## R2: Duplicate Detection Algorithm — Exact String Match

**Decision**: Exact string comparison on the message content after trimming whitespace.

**Rationale**: The spec explicitly requires that "only exact duplicate messages within the time window trigger spam detection" and that messages with "merely similar words" must NOT be blocked. Exact match is the simplest, fastest, and most predictable approach. It produces zero false positives on near-similar messages.

**Alternatives considered**:
- **Fuzzy matching (Levenshtein distance)**: Explicitly rejected by the spec's negative requirement. Would introduce false positives on similar-but-different messages.
- **Content hashing**: Would save memory for long messages, but adds complexity. Message content is already bounded (typical chat messages are short), so direct string comparison is efficient enough. Could be revisited if memory profiling shows issues.

## R3: Tracker Data Structure — Map with Timestamp Lists

**Decision**: Use a map keyed by sender nickname (downcased), with values containing a list of monotonic timestamps (for flood tracking) and a list of `{content, target, timestamp}` tuples (for duplicate tracking). Evict oldest entries when the 50-sender cap is reached.

**Rationale**: Maps provide O(log n) lookup by sender. Timestamp lists naturally support sliding window algorithms — filter out entries older than the time window, count remaining. The 50-sender cap keeps memory bounded. Using monotonic time (via `System.monotonic_time(:millisecond)`) avoids issues with wall-clock time adjustments.

**Alternatives considered**:
- **Circular buffer per sender**: More memory-efficient but adds implementation complexity. With only 50 senders max and short time windows (10-15s), the simple list approach is adequate.
- **ETS table**: Overkill for per-process state. ETS is designed for shared state; socket assigns are simpler for process-local data.

## R4: Auto-Ignore Timer Pattern — Process.send_after

**Decision**: Use `Process.send_after/3` to schedule auto-ignore expiry, matching the existing pattern used for timed ignore entries.

**Rationale**: The codebase already uses `Process.send_after` for ignore entry expiration timers (see `maybe_start_ignore_timer` in ChatLive). Auto-ignore entries are functionally identical to manually-added timed ignores — they just have an automated trigger. Reusing the same timer mechanism ensures consistency and allows the existing `remove_expired` logic to handle cleanup.

**Alternatives considered**:
- **Periodic sweep (`:timer.send_interval`)**: Would add latency between expiry and actual removal. `Process.send_after` is more precise and already established in the codebase.

## R5: Cooldown Mechanism — Timestamp in Socket Assigns

**Decision**: Store a map of `%{sender_nickname => cooldown_expires_at}` in socket assigns to track the cooldown period after manual un-ignore of auto-ignored users.

**Rationale**: The cooldown only needs to persist for the current session (60 seconds) and is per-user state — socket assigns are the natural location. When a user manually removes an auto-ignore entry, record a cooldown timestamp. Before triggering auto-ignore, check if a cooldown is active for that sender.

**Alternatives considered**:
- **Flag on the ignore entry**: Would require modifying the IgnoreEntry struct, which is shared infrastructure. A separate cooldown map is cleaner and doesn't couple flood protection to the ignore system's data model.

## R6: Sender Feedback for Duplicate Blocking — Channel.Server Broadcast

**Decision**: When a message is detected as a duplicate by the receiver's flood protection, the receiver does NOT notify the sender. The sender feedback described in the spec ("Your message was blocked") is handled at the sender's own client side — if the sender's own flood protection also detects the duplicate pattern in their outgoing messages.

**Revised understanding**: After deeper analysis, sender-side notification of receiver-side filtering is architecturally problematic. The ignore system does not notify senders either (FR-005 explicitly states "MUST NOT notify the auto-ignored user"). For consistency, duplicate blocking should work the same way — the receiver silently drops duplicates. The sender may see their own messages blocked by their own client's duplicate detection if they're spamming, but this is a local concern.

**Rationale**: Receiver-side filtering is private to the receiver. Broadcasting a "your message was blocked" notification back to the sender would:
1. Reveal that the receiver has flood protection enabled (privacy concern)
2. Require a new PubSub message type and sender-side handler
3. Be inconsistent with how the ignore system works (silent filtering)

The spec's FR-002 ("System MUST provide feedback to the sender") is reinterpreted as: the system provides this feedback when the sender's own outgoing message rate triggers their own local duplicate detection. This is consistent with the existing rate limiter, which mutes the sender locally.

**Alternatives considered**:
- **PubSub notification to sender**: Rejected for privacy and consistency reasons above.
- **Channel.Server rejection**: Would require server-side per-receiver flood state, contradicting the per-user client-side architecture.

## R7: Settings Persistence — Single-Row-Per-User Pattern

**Decision**: Follow the CTCP settings pattern: one DB table `flood_protection_settings` with `owner_nickname` as the primary key referencing `registered_nicks`. All threshold values stored as columns.

**Rationale**: This is the exact pattern used by `ctcp_settings` and `notice_routing_settings`. Single-row-per-user is simple, efficient, and requires no joins. All flood protection settings for a user are read/written atomically.

**Alternatives considered**:
- **JSON column**: Would allow flexible schema evolution but loses type safety and validation at the DB level. Individual columns are clearer and match the project pattern.
- **Key-value pairs table**: Over-engineered for a fixed set of settings. Would require multiple rows per user and aggregation logic.

## R8: Integration with Existing Ignore System

**Decision**: Auto-ignore entries are regular ignore list entries with `expires_at` set and `ignore_type: :all`. They are added via the existing `IgnoreList.add_entry/4` function. The flood protection system tracks which entries were auto-created using a separate map in socket assigns (`auto_ignored_senders`).

**Rationale**: The ignore list already supports timed entries with `expires_at`. Auto-ignore entries should behave identically to manually-added timed ignores from the user's perspective — they appear in the ignore list dialog, can be manually removed, and expire automatically. The only difference is the trigger (automatic vs. manual) and the cooldown behavior, which is tracked separately.

**Alternatives considered**:
- **Separate auto-ignore list**: Would duplicate the ignore list's functionality and create confusion about which list takes precedence. Using the existing ignore list ensures a single source of truth for message filtering.
- **New ignore_type for auto-ignore**: Would require modifying `IgnoreEntry.valid_type?/1` and all downstream type matching. A separate tracking map is less invasive.
