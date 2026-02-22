# Implementation Plan: CTCP (Client-to-Client Protocol)

**Branch**: `012-ctcp-system` | **Date**: 2026-02-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/012-ctcp-system/spec.md`

## Summary

Implement simulated CTCP (Client-to-Client Protocol) for RetroHexChat, enabling users to query information about other users' clients and measure connection latency via `/ctcp <target> <type>` supporting PING, VERSION, TIME, and FINGER. The system uses PubSub user-to-user messaging for request/reply delivery, Process.send_after for 10-second timeouts, socket assigns for pending request tracking, and a per-sender-target rate limiter. A retro-styled settings dialog allows customization of reply strings and enable/disable toggling, with Ecto-backed persistence for registered users.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, retro design system
**Storage**: PostgreSQL 16+ (new `ctcp_settings` table) + in-memory Session state for guests
**Testing**: ExUnit with `async: true`, Floki for LiveView tests
**Target Platform**: Web (Phoenix LiveView)
**Project Type**: Umbrella (retro_hex_chat + retro_hex_chat_web)
**Performance Goals**: CTCP replies within 1 second for online users; self-CTCP instant
**Constraints**: 10-second timeout, 3 requests per target per 30-second window, 200-char max for custom strings
**Scale/Scope**: Same as existing user base; rate limiting prevents abuse

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | PASS | Pure Elixir/Phoenix/LiveView, no JS frameworks, PostgreSQL only |
| II. Umbrella with Bounded Contexts | PASS | Domain logic in `retro_hex_chat` (Chat context for settings, Commands for handler), web layer in `retro_hex_chat_web` |
| III. OTP Process Architecture | PASS | No new GenServers needed — uses existing PubSub + socket assigns for pending requests. Rate limiting via socket assigns (per-LiveView process) |
| IV. Test-First Development | PASS | Unit tests for handler + domain modules, LiveView tests for request/reply flow, settings dialog |
| V. Contracts and Behaviours | PASS | `/ctcp` command implements existing `Handler` behaviour |
| VI. Static Analysis | PASS | @spec on all public functions, Credo/Dialyxir clean |
| VII. Lean LiveViews | PASS | LiveView delegates to domain modules (CtcpSettings, handler). PubSub via `user:#{nickname}` topic |
| VIII. retro Design Fidelity | PASS | Settings dialog uses retro design system pattern matching existing dialogs |
| IX. Hot/Cold Data Separation | PASS | Hot: Session struct (in-memory settings + pending requests). Cold: PostgreSQL for registered user settings |
| X. Scalable Architecture | PASS | PubSub-based, no single bottleneck. Rate limiting is per-socket (scales with connections) |
| XI. User-Facing Documentation | PASS | Help topics for /ctcp command, CTCP feature overview, CTCP settings |

All gates pass. No violations to justify.

## Project Structure

### Documentation (this feature)

```text
specs/012-ctcp-system/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
apps/
├── retro_hex_chat/                              # Domain layer
│   ├── lib/retro_hex_chat/
│   │   ├── chat/
│   │   │   ├── ctcp_settings.ex                 # NEW: Domain module (new/get/set/save/load)
│   │   │   └── schemas/
│   │   │       └── ctcp_setting.ex              # NEW: Ecto schema for ctcp_settings table
│   │   ├── commands/
│   │   │   ├── handlers/
│   │   │   │   └── ctcp.ex                      # NEW: /ctcp command handler
│   │   │   ├── handler.ex                       # MODIFY: Add {:ok, :ctcp, map()} to result type
│   │   │   └── registry.ex                      # MODIFY: Register "ctcp" command
│   │   └── accounts/
│   │       └── session.ex                       # MODIFY: Add ctcp_settings, ctcp_pending, last_message_at fields
│   ├── priv/repo/migrations/
│   │   └── 2026MMDDHHMMSS_create_ctcp_settings.exs  # NEW: Migration
│   └── test/
│       └── retro_hex_chat/
│           ├── chat/
│           │   └── ctcp_settings_test.exs       # NEW: Unit tests for domain module
│           └── commands/
│               └── handlers/
│                   └── ctcp_test.exs            # NEW: Unit tests for handler
│
└── retro_hex_chat_web/                          # Web layer
    ├── lib/retro_hex_chat_web/
    │   ├── live/
    │   │   └── chat_live.ex                     # MODIFY: handle_dispatch_result, handle_info, handle_event
    │   └── components/
    │       ├── ctcp_settings_dialog.ex          # NEW: retro-styled settings dialog component
    │       └── menu_bar.ex                      # MODIFY: Add "CTCP Settings" to Tools menu
    ├── assets/css/
    │   └── layout.css                           # MODIFY: Add .chat-ctcp styles (if needed)
    └── test/
        └── retro_hex_chat_web/
            └── live/
                └── chat_live_ctcp_test.exs      # NEW: LiveView integration tests
```

**Structure Decision**: Follows existing umbrella structure. CTCP settings belong in `Chat` bounded context (same as notice_routing, highlight_words, ignore_list). The `/ctcp` command handler lives in `Commands.Handlers`. Rate limiting is implemented via socket assigns (a simple map tracking timestamps per target) rather than the ETS-based `RateLimit.Limiter` — this is simpler and sufficient since CTCP rate limiting is per-sender-target pair within a single LiveView process.

## Key Design Decisions

### 1. CTCP Request/Reply Flow

The CTCP system uses PubSub for request/reply delivery, following the same pattern as notices:

```
Sender types /ctcp Alice ping
  → Handler returns {:ok, :ctcp, %{target: "Alice", type: :ping}}
  → handle_dispatch_result calls handle_ctcp_send/4
  → Validates target online (validate_target_online/1)
  → Self-CTCP: immediate reply, no PubSub needed
  → Remote: PubSub.broadcast to "user:Alice" with {:ctcp_request, %{...}}
  → Starts 10s timeout via Process.send_after
  → Stores pending request in socket assigns

Alice's LiveView receives {:ctcp_request, ...}
  → Checks ctcp_enabled in session.ctcp_settings
  → If enabled: broadcasts {:ctcp_reply, %{...}} to "user:#{sender}"
  → Shows "* CTCP PING request from Bob" as system message

Bob's LiveView receives {:ctcp_reply, ...}
  → Matches pending request by request_id
  → Cancels timeout timer
  → Calculates latency (for PING) or displays reply value
  → Shows "* CTCP PING reply from Alice: 45ms"
```

### 2. Pending Request Tracking

Pending CTCP requests are stored in socket assigns (not Session struct) since they are ephemeral and LiveView-specific:

```elixir
# In socket assigns:
ctcp_pending: %{
  "req_12345" => %{
    target: "Alice",
    type: :ping,
    sent_at: System.monotonic_time(:millisecond),
    timer_ref: #Reference<...>
  }
}
```

Using `System.monotonic_time(:millisecond)` for PING latency measurement (more accurate than DateTime).

### 3. Rate Limiting

CTCP rate limiting uses a simple map in socket assigns tracking send timestamps per target:

```elixir
# In socket assigns:
ctcp_rate_limits: %{
  "alice" => [timestamp1, timestamp2, timestamp3]  # monotonic ms
}
```

On each CTCP send, prune timestamps older than 30 seconds, then check if count < 3. This is simpler than ETS and scoped to the sender's LiveView process.

### 4. Idle Time Tracking

For FINGER default text ("Alice - idle 5 minutes"), we need to track the last message timestamp. Add `last_message_at` to Session struct, updated on every sent message. Idle time = `DateTime.diff(now, last_message_at)`.

### 5. CTCP Settings Persistence

Following the notice_routing pattern:
- In-memory: `ctcp_settings` map in Session struct
- Persistent: `ctcp_settings` table with FK to `registered_nicks`
- Load on identify via `load_persisted_data`
- Save via `Task.start` on settings change (identified users only)

### 6. No New Message Type

CTCP system messages (requests and replies) use the existing `:system` message type. There is no need for a `:ctcp` rendering type since all CTCP messages are displayed as `* CTCP ...` system messages. This avoids adding unnecessary complexity to the rendering pipeline.

## Complexity Tracking

No constitution violations. No complexity tracking needed.
