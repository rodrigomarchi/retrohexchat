# Implementation Plan: Special Messages

**Branch**: `020-special-messages` | **Date**: 2026-02-13 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/020-special-messages/spec.md`

## Summary

Add four server communication mechanisms to RetroHexChat: Message of the Day (MOTD) displayed on connect and via `/motd` command, per-channel welcome messages shown to users on first join, `/wallops` operator broadcasts to `+w` mode users, and `/announce` global announcements that bypass ignore lists. The implementation introduces server-level admin/operator roles via application configuration, two new database tables (server_settings, channel_welcome_messages), eight new slash command handlers, a `/umode` command for user mode management, and three new PubSub topics for server-wide messaging.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, 98.css
**Storage**: PostgreSQL 16+ (2 new tables: `server_settings`, `channel_welcome_messages`) + in-memory Session state for user modes and welcome tracking + in-memory cache for MOTD
**Testing**: ExUnit with async: true, Mox, ExMachina, Floki (for styled message tests)
**Target Platform**: Web (Phoenix LiveView, all browsers)
**Project Type**: Umbrella web application (retro_hex_chat + retro_hex_chat_web)
**Performance Goals**: MOTD retrieval and display must be sub-millisecond (in-memory cache). Welcome message lookup must be sub-millisecond (Channel.Server GenServer state). Wallops and announcement PubSub delivery within 100ms.
**Constraints**: Admin/operator roles depend on NickServ identification — not just config presence. Announcements MUST bypass ignore lists. Welcome messages shown once per session per channel. No new OTP processes needed — reuse existing Channel.Server and Session patterns.
**Scale/Scope**: ~15 new files, ~10 modified files, 2 new migrations. ~14 new test files, ~2 modified test files.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | Elixir & Phoenix Exclusive Stack | PASS | Pure Elixir/Phoenix/LiveView. No JS frameworks. PostgreSQL for persistence. 98.css for UI styling. |
| II | Umbrella App with Bounded Contexts | PASS | Domain logic in `retro_hex_chat` (Accounts, Services, Commands, Channels contexts). Web layer in `retro_hex_chat_web`. New `ServerRoles` in Accounts, new schemas in Services. No cross-context coupling. |
| III | OTP Process Architecture | PASS | No new processes. Reuses existing Channel.Server for welcome messages. MOTD cache uses Application env or Agent (single value). PubSub for transient messages (wallops, announcements). |
| IV | Test-First Development | PASS | Unit tests for ServerRoles, Session helpers, Motd service, command handlers. Integration tests for DB operations. LiveView tests for MOTD display, welcome message flow, announcement delivery. |
| V | Contracts and Behaviours | PASS | 8 new command handlers, each implementing Handler behaviour. All new public functions have @spec. ServerRoles module has clear function contracts. |
| VI | Static Analysis from Day One | PASS | All new modules have @spec on public functions. `mix credo --strict` and `mix dialyzer` enforced. |
| VII | Lean LiveViews & Component Architecture | PASS | ChatLive delegates to Services.Motd, Channels.Server, and command handlers. PubSub handlers are routing-only. New PubSub topics follow convention: `"server:announcements"`, `"server:wallops"`, `"server:settings"`. |
| VIII | Windows 98 Design Fidelity | PASS | MOTD uses bordered container matching 98.css patterns. Announcements use amber/yellow background matching Windows 98 warning dialogs. Wallops uses italic text in Status Window. |
| IX | Hot/Cold Data Separation | PASS | MOTD text: cold (PostgreSQL) + hot (in-memory cache). Welcome messages: cold (PostgreSQL) + hot (Channel.Server state). User modes, welcome tracking: hot only (Session struct, session-scoped). Wallops/announcements: transient (PubSub, no storage). |
| X | Scalable Architecture | PASS | PubSub-based delivery scales across nodes. Per-channel welcome messages cached in existing GenServers. No global mutable state beyond MOTD cache (single value, rarely changes). Config-based roles are node-local but consistent across cluster. |
| XI | User-Facing Documentation | PASS | 9 new help topics: 8 commands (/motd, /setmotd, /clearmotd, /setwelcome, /clearwelcome, /wallops, /announce, /umode) + 1 feature overview (Special Messages). Commands overview topic updated. |

**Gate result**: ALL PASS — no violations.

**Post-Phase 1 re-check**: All design decisions maintain compliance. The `ServerRoles` module reads config and checks `identified` flag without querying NickServ directly (Principle II). MOTD cache is a single value in Application env — no ETS or new GenServer needed (Principle III). Welcome messages cached in existing Channel.Server state (Principle IX). Three new PubSub topics follow `"server:*"` convention (Principle VII).

## Project Structure

### Documentation (this feature)

```text
specs/020-special-messages/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0: research decisions
├── data-model.md        # Phase 1: entity/struct changes
├── quickstart.md        # Phase 1: implementation order guide
├── contracts/           # Phase 1: API contracts
│   ├── domain-api.md    # Domain layer contracts
│   └── web-layer.md     # Web layer contracts
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
apps/
├── retro_hex_chat/                          # Domain layer
│   ├── lib/retro_hex_chat/
│   │   ├── accounts/
│   │   │   ├── session.ex                   # MODIFY: add user_modes, welcomed_channels, helper functions
│   │   │   └── server_roles.ex              # NEW: admin?/2, server_operator?/2
│   │   ├── services/
│   │   │   ├── server_setting.ex            # NEW: Ecto schema for server_settings table
│   │   │   ├── channel_welcome_message.ex   # NEW: Ecto schema for channel_welcome_messages table
│   │   │   ├── motd.ex                      # NEW: MOTD management with cache
│   │   │   └── queries.ex                   # MODIFY: add settings and welcome query functions
│   │   ├── channels/
│   │   │   └── server.ex                    # MODIFY: load/cache welcome messages, set_welcome/3, clear_welcome/2, get_welcome/1
│   │   ├── commands/
│   │   │   ├── handler.ex                   # MODIFY: add is_admin, is_server_operator to context type
│   │   │   ├── registry.ex                  # MODIFY: register 8 new commands
│   │   │   └── handlers/
│   │   │       ├── set_motd.ex              # NEW: /setmotd command
│   │   │       ├── clear_motd.ex            # NEW: /clearmotd command
│   │   │       ├── motd.ex                  # NEW: /motd command
│   │   │       ├── set_welcome.ex           # NEW: /setwelcome command
│   │   │       ├── clear_welcome.ex         # NEW: /clearwelcome command
│   │   │       ├── wallops.ex               # NEW: /wallops command
│   │   │       ├── announce.ex              # NEW: /announce command
│   │   │       └── umode.ex                 # NEW: /umode command
│   │   └── chat/
│   │       └── help_topics/
│   │           └── special_messages.ex      # NEW: 9 help topics for this feature
│   ├── priv/repo/migrations/
│   │   ├── *_create_server_settings.exs     # NEW: server_settings table
│   │   └── *_create_channel_welcome_messages.exs # NEW: channel_welcome_messages table
│   └── test/
│       └── retro_hex_chat/
│           ├── accounts/
│           │   ├── server_roles_test.exs    # NEW: test role checks
│           │   └── session_test.exs         # MODIFY: test new fields/functions
│           ├── services/
│           │   ├── motd_test.exs            # NEW: test MOTD service
│           │   ├── server_setting_test.exs  # NEW: test schema
│           │   └── channel_welcome_message_test.exs # NEW: test schema
│           ├── channels/
│           │   └── server_test.exs          # MODIFY: test welcome message caching
│           └── commands/handlers/
│               ├── set_motd_test.exs        # NEW
│               ├── clear_motd_test.exs      # NEW
│               ├── motd_test.exs            # NEW
│               ├── set_welcome_test.exs     # NEW
│               ├── clear_welcome_test.exs   # NEW
│               ├── wallops_test.exs         # NEW
│               ├── announce_test.exs        # NEW
│               └── umode_test.exs           # NEW
└── retro_hex_chat_web/                      # Web layer
    ├── lib/retro_hex_chat_web/
    │   ├── live/
    │   │   ├── chat_live.ex                 # MODIFY: subscribe to new PubSub topics, display MOTD on mount
    │   │   └── chat_live/
    │   │       ├── command_dispatch.ex      # MODIFY: add is_admin, is_server_operator to context
    │   │       ├── pubsub_handlers.ex       # MODIFY: route new event types
    │   │       ├── pubsub_handlers/
    │   │       │   └── server_messages.ex   # NEW: handle announcements, wallops, motd_updated
    │   │       ├── ui_action_handlers.ex    # MODIFY: route new UI actions
    │   │       ├── ui_actions/
    │   │       │   └── server_messages.ex   # NEW: handle show_motd, set_welcome, clear_welcome, set_user_mode
    │   │       └── helpers/
    │   │           └── channel.ex           # MODIFY: welcome message display on join
    │   └── assets/css/
    │       └── messages.css (or similar)    # MODIFY: MOTD, announcement, wallops styles
    └── test/
        └── retro_hex_chat_web/
            └── live/
                └── chat_live/
                    └── special_messages_test.exs # NEW: LiveView integration tests
```

**Structure Decision**: Existing umbrella structure. All domain logic in `retro_hex_chat`, all web/UI in `retro_hex_chat_web`. New `ServerRoles` module in Accounts context. New schemas and `Motd` service in Services context. 8 new command handlers in Commands context. Welcome message caching extends Channels context. Two new PubSub handler/UI action sub-modules in the web layer. Two new migrations.

## Complexity Tracking

> No violations found — table not needed.
