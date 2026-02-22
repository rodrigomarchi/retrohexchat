# Implementation Plan: Favorites / Bookmarks

**Branch**: `015-favorites` | **Date**: 2026-02-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/015-favorites/spec.md`

## Summary

Implement a channel favorites/bookmarks system allowing users to save, organize, and quickly access frequently visited channels. Includes a Favorites menu in the menu bar, treebar right-click context menu for adding favorites, an Organize Favorites dialog for management, auto-join on connect for marked favorites, and encrypted password storage for +k channels. Follows the existing `AutoJoinList` multi-row persistence pattern with a new `favorites` table.

## Technical Context

**Language/Version**: Elixir 1.17+ / OTP 27+
**Primary Dependencies**: Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, retro design system, Plug.Crypto (transitive, for password encryption)
**Storage**: PostgreSQL 16+ (new `favorites` table) + in-memory Session state for guests
**Testing**: ExUnit with LiveView testing, async: false for LiveView tests
**Target Platform**: Web browser (Phoenix LiveView)
**Project Type**: Umbrella (retro_hex_chat + retro_hex_chat_web)
**Performance Goals**: Favorites menu renders instantly, auto-join completes within 2s of connect
**Constraints**: Max 16-char nicknames, max 50-char channel names, passwords encrypted at rest
**Scale/Scope**: No arbitrary limit on favorites count; typical user has 5-20

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Elixir & Phoenix Exclusive | PASS | Pure Elixir/Phoenix/LiveView, no JS frameworks |
| II. Umbrella with Bounded Contexts | PASS | Domain module in `retro_hex_chat`, UI in `retro_hex_chat_web` |
| III. OTP Process Architecture | PASS | No new processes needed; uses existing channel GenServers for join |
| IV. Test-First Development | PASS | Tests written before implementation per task plan |
| V. Contracts and Behaviours | PASS | No new commands or behaviours needed |
| VI. Static Analysis from Day One | PASS | @spec on all public functions, Credo/Dialyzer/format enforced |
| VII. Lean LiveViews | PASS | All logic in domain module (Favorites), LiveView delegates only |
| VIII. retro Design Fidelity | PASS | retro dialogs, context menus, menu bar styling |
| IX. Hot/Cold Data Separation | PASS | In-memory session for runtime, PostgreSQL for persistence |
| X. Scalable Architecture | PASS | Simple list data, no process bottlenecks |
| XI. User-Facing Documentation | PASS | Help topics for Favorites, Organize Favorites |

**Post-design re-check**: All principles satisfied. No violations.

## Project Structure

### Documentation (this feature)

```text
specs/015-favorites/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── favorites.md
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
apps/retro_hex_chat/
├── lib/retro_hex_chat/
│   ├── accounts/
│   │   └── session.ex                          # Modified: add favorites field
│   └── chat/
│       ├── favorites.ex                        # NEW: domain module (CRUD, save, load)
│       ├── favorite_entry.ex                   # NEW: entry struct
│       ├── password_encryption.ex              # NEW: AES-GCM encrypt/decrypt
│       └── schemas/
│           └── favorite_entry.ex               # NEW: Ecto schema
├── priv/repo/migrations/
│   └── YYYYMMDD_create_favorites.exs           # NEW: migration
└── test/retro_hex_chat/chat/
    ├── favorites_test.exs                      # NEW: domain tests
    └── password_encryption_test.exs            # NEW: encryption tests

apps/retro_hex_chat_web/
├── lib/retro_hex_chat_web/
│   ├── components/
│   │   ├── menu_bar.ex                         # Modified: add Favorites menu
│   │   ├── treebar.ex                          # Modified: add right-click event
│   │   ├── treebar_context_menu.ex             # NEW: channel context menu
│   │   ├── favorite_dialog.ex                  # NEW: Add/Edit Favorite dialog
│   │   └── organize_favorites_dialog.ex        # NEW: Organize Favorites dialog
│   └── live/
│       └── chat_live.ex                        # Modified: assigns, handlers, auto-join
├── assets/css/
│   └── layout.css                              # Modified: treebar context menu styles (if needed)
└── test/retro_hex_chat_web/live/
    ├── favorites_test.exs                      # NEW: favorites LiveView tests
    ├── organize_favorites_test.exs             # NEW: organize dialog tests
    └── favorites_autojoin_test.exs             # NEW: auto-join tests

apps/retro_hex_chat/lib/retro_hex_chat/chat/
    └── help_topics.ex                          # Modified: add Favorites help topics
```

**Structure Decision**: Follows the established umbrella pattern. Domain logic (Favorites, FavoriteEntry, PasswordEncryption) lives in `retro_hex_chat`. UI components (dialogs, context menu, menu updates) live in `retro_hex_chat_web`. The `favorites` table follows the `autojoin_entries` multi-row pattern.

## Complexity Tracking

> No constitution violations. Table intentionally left empty.
