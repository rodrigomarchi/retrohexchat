# RetroHexChat

A real-time IRC client for the web — built with Elixir, Phoenix LiveView, and OTP — wearing a Windows 98 skin.

RetroHexChat recreates the experience of classic IRC clients like mIRC, complete with multi-channel chat, private messaging, NickServ/ChanServ services, moderation tools, and a faithful dark-themed Windows 98 UI powered by [98.css](https://jdan.github.io/98.css/).

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [OTP Supervision Tree](#otp-supervision-tree)
- [Bounded Contexts](#bounded-contexts)
- [Command System](#command-system)
- [UI Components](#ui-components)
- [Database Schema](#database-schema)
- [Getting Started](#getting-started)
- [Running Tests](#running-tests)
- [Static Analysis](#static-analysis)
- [Design Principles](#design-principles)
- [License](#license)

---

## Features

### Chat
- **Multi-channel messaging** — Join multiple channels, switch between them in an MDI layout
- **Private messaging** — `/msg` and `/query` for direct 1-on-1 conversations
- **Action messages** — `/me` for expressive actions
- **Message history** — Persistent storage with cursor-based pagination and infinite scroll
- **Full-text search** — PostgreSQL trigram search across message history
- **Unread indicators** — Visual badges on channels with unread messages

### Channels
- **Channel modes** — `+i` (invite-only), `+m` (moderated), `+t` (topic lock), `+k` (key/password), `+l` (user limit)
- **Role system** — Operators (`@`), Voiced (`+`), and regular users
- **Topic management** — Set and view channel topics with permission control
- **Channel list** — Browse active channels with topic, user count, and search/filter

### Services
- **NickServ** — Register nicknames, identify, ghost sessions, 60-second enforce timer
- **ChanServ** — Register channels, manage access lists (Founder → SOP → AOP → VOP)

### Moderation
- **Kick** — Remove users from channels with optional reason
- **Ban** — Persistent bans stored in PostgreSQL
- **Rate limiting** — Flood control with mute enforcement via ETS counters

### UI
- **Windows 98 aesthetic** — 98.css with a custom dark theme
- **MDI layout** — Treebar (channels/PMs) | Chat area | Nicklist
- **Context menus** — Right-click users for Query, Whois, Kick, Ban, Op, Voice
- **Command palette** — `Ctrl+/` to browse all slash commands
- **Keyboard shortcuts** — `↑`/`↓` history, `Tab` completion, `Ctrl+F` search
- **Real-time presence** — Online/away status tracking across channels

---

## Architecture

RetroHexChat is a **Phoenix umbrella application** with strict separation between domain logic and web concerns:

```
┌─────────────────────────────────────────────────────────┐
│                    Browser (LiveView)                    │
│  ConnectLive ──→ ChatLive ──→ ChannelListLive           │
│  15 function components · 4 JS hooks · 98.css dark theme│
└─────────────────────┬───────────────────────────────────┘
                      │ Phoenix.PubSub
┌─────────────────────▼───────────────────────────────────┐
│              retro_hex_chat (Domain Layer)               │
│                                                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────┐  │
│  │ Accounts │ │   Chat   │ │ Channels │ │  Commands  │  │
│  │          │ │          │ │          │ │            │  │
│  │ Sessions │ │ Messages │ │ Server   │ │ 18 Handlers│  │
│  │ NickValid│ │ History  │ │ Modes    │ │ Parser     │  │
│  │ Policy   │ │ Search   │ │ Policy   │ │ Dispatcher │  │
│  └──────────┘ └──────────┘ └──────────┘ └───────────┘  │
│                                                         │
│  ┌──────────┐ ┌──────────┐ ┌───────────┐               │
│  │ Services │ │ Presence │ │ RateLimit │               │
│  │          │ │          │ │           │               │
│  │ NickServ │ │ Tracker  │ │ Limiter   │               │
│  │ ChanServ │ │ (Phoenix │ │ Table     │               │
│  │ AccessLst│ │ Presence)│ │ (ETS)     │               │
│  └──────────┘ └──────────┘ └───────────┘               │
└─────────────────────┬───────────────────────────────────┘
                      │
        ┌─────────────▼──────────────┐
        │       PostgreSQL 16+       │
        │                            │
        │  messages · private_msgs   │
        │  registered_nicks/channels │
        │  access_list · bans        │
        │  GIN trigram indexes       │
        └────────────────────────────┘
```

### Hot/Cold Data Separation

| Layer | Storage | Data | Access Pattern |
|-------|---------|------|----------------|
| **Hot** | GenServer (per channel) | Topic, modes, bans, membership | Sub-millisecond reads |
| **Hot** | ETS | Rate-limit counters, mute state | Concurrent reads |
| **Hot** | Phoenix.Presence | Online/away users per channel | Real-time tracking |
| **Cold** | PostgreSQL | Message history, registered nicks/channels | Cursor-based pagination |

---

## Tech Stack

| Layer | Technology | Role |
|-------|-----------|------|
| Language | **Elixir 1.17+** / OTP 27+ | Backend, domain logic, concurrency |
| Framework | **Phoenix 1.8** | HTTP, WebSocket, PubSub |
| Reactive UI | **Phoenix LiveView 1.0+** | Server-rendered reactive UI, zero JS frameworks |
| Database | **PostgreSQL 16+** | Persistent storage, full-text search |
| Design System | **98.css** + custom dark theme | Windows 98 aesthetic |
| Assets | **esbuild** | JS/CSS bundling |
| HTTP Server | **Bandit** | HTTP/1.1 + WebSocket |
| Auth | **bcrypt_elixir** | Password hashing for NickServ |
| Testing | **ExUnit, Mox, ExMachina, StreamData, Floki** | Full test pyramid |
| Static Analysis | **Credo, Dialyxir** | Lint + type checking |

---

## Project Structure

```
retro_hex_chat/
├── apps/
│   ├── retro_hex_chat/                  # Domain app (pure Elixir)
│   │   ├── lib/retro_hex_chat/
│   │   │   ├── application.ex           # OTP supervision tree
│   │   │   ├── accounts/               # Nickname validation, sessions
│   │   │   ├── channels/               # GenServer per channel, modes, policy
│   │   │   ├── chat/                   # Messages, history, search
│   │   │   ├── commands/               # Parser, dispatcher, 18 handlers
│   │   │   ├── presence/               # Phoenix.Presence tracker
│   │   │   ├── rate_limit/             # ETS-backed flood control
│   │   │   └── services/               # NickServ + ChanServ bots
│   │   ├── priv/repo/migrations/       # Database migrations
│   │   └── test/                       # Domain tests (unit + integration)
│   │
│   └── retro_hex_chat_web/             # Web app (Phoenix + LiveView)
│       ├── lib/retro_hex_chat_web/
│       │   ├── live/
│       │   │   ├── connect_live.ex      # Nickname entry screen
│       │   │   ├── chat_live.ex         # Main chat MDI screen
│       │   │   └── channel_list_live.ex # Channel browser screen
│       │   └── components/             # 15 function components
│       │       ├── window.ex            # Win98 window chrome
│       │       ├── title_bar.ex         # Blue gradient title bar
│       │       ├── menu_bar.ex          # File/Edit/View/Help menus
│       │       ├── toolbar.ex           # Icon button toolbar
│       │       ├── treebar.ex           # Channel/PM tree sidebar
│       │       ├── chat_message.ex      # Message rendering
│       │       ├── nicklist.ex          # User list (@ops, +voiced)
│       │       ├── status_bar.ex        # Bottom status bar
│       │       ├── command_palette.ex   # Ctrl+/ command picker
│       │       ├── context_menu.ex      # Right-click user menu
│       │       ├── search_bar.ex        # In-chat search
│       │       ├── scroll_loader.ex     # Infinite scroll loader
│       │       └── dialog.ex            # Modal dialogs
│       ├── assets/
│       │   ├── css/dark-theme.css       # Win98 dark theme
│       │   └── js/hooks/               # 4 LiveView hooks
│       │       ├── scroll_hook.js       # Infinite scroll + auto-scroll
│       │       ├── command_palette_hook.js # Ctrl+/ + keyboard shortcuts
│       │       ├── keyboard_hook.js     # ↑/↓ history, Tab completion
│       │       └── sound_hook.js        # Web Audio API notifications
│       └── test/                        # Web tests (LiveView + E2E)
│
├── config/                              # Environment configs (dev/test/prod)
├── .specify/                            # Speckit design artifacts
│   └── memory/constitution.md           # 10 governing principles
└── CLAUDE.md                            # Development guidelines
```


---

## OTP Supervision Tree

Every channel runs as an isolated OTP process. If one channel crashes, others are unaffected.

```
RetroHexChat.Supervisor (:one_for_one)
│
├── RetroHexChat.Repo
│     Ecto database connection pool
│
├── DNSCluster
│     Clustering via DNS (production)
│
├── Phoenix.PubSub (RetroHexChat.PubSub)
│     Message broadcast backbone
│     Topics: "channel:#{name}" · "user:#{nickname}" · "pm:#{sorted_ids}"
│
├── Registry (ChannelRegistry)
│     Named process lookup via {:via, Registry, {ChannelRegistry, "#lobby"}}
│
├── Channels.Supervisor (DynamicSupervisor)
│     Spawns/terminates channel processes on demand
│     │
│     ├── Channels.Server "#lobby"     ← GenServer holding channel state
│     ├── Channels.Server "#general"      (topic, modes, bans, members)
│     └── Channels.Server "#random"       Transient restart: empty
│                                         unregistered channels stop gracefully
│
├── Presence.Tracker
│     Phoenix.Presence — distributed user tracking per channel
│
├── RateLimit.Table
│     GenServer owning an ETS table for flood-control counters
│
├── Services.NickServ
│     GenServer — nickname registration, identify, ghost, 60s enforce timer
│
└── Services.ChanServ
      GenServer — channel registration, access lists (founder/sop/aop/vop)
```

### Channel Process Lifecycle

```
User sends /join #new-channel
        │
        ▼
┌───────────────────────┐     ┌──────────────────────────┐
│  Registry.lookup/1    │────▶│  Channel exists?          │
└───────────────────────┘     │  YES → join existing      │
                              │  NO  → DynamicSupervisor  │
                              │        starts new Server   │
                              └──────────────────────────┘
                                        │
                              ┌─────────▼────────────┐
                              │  Channels.Server     │
                              │  init/1:             │
                              │  • Load registered   │
                              │    state from DB     │
                              │  • Set initial modes │
                              │  • Subscribe PubSub  │
                              └──────────────────────┘

Last user leaves unregistered channel
        │
        ▼
  Server detects empty membership
        │
        ▼
  GenServer stops (transient restart = no respawn)
```

---

## Bounded Contexts

### Accounts

Manages user identity within a session. No persistent user accounts — nicknames are the identity primitive (like classic IRC).

```
Accounts
├── Session         — In-memory user state: channels, PMs, away status
├── NicknameValidator — 1-16 chars, alphanumeric + _-[]{}^
└── Policy          — Authorization checks (can user perform action?)
```

### Chat

Handles message persistence, retrieval, and search.

```
Chat
├── Message         — Ecto schema: channel messages (system, action, regular)
├── PrivateMessage   — Ecto schema: direct messages between users
├── Queries         — Cursor-based pagination (before_id), batch inserts
├── Service         — High-level operations: send, history, search
└── Search          — PostgreSQL pg_trgm trigram full-text search
```

### Channels

The core real-time engine. Each active channel is a GenServer process.

```
Channels
├── Server          — GenServer: topic, modes, bans, members, message dispatch
├── Supervisor      — DynamicSupervisor: process lifecycle management
├── Registry        — via_tuple named process lookup
├── Membership      — Roles: :operator, :voiced, :regular
├── Modes           — +i (invite) +m (moderated) +t (topic-lock) +k (key) +l (limit)
├── Policy          — can_join? can_speak? can_kick? can_change_topic?
├── Queries         — DB queries for registered channels
└── Events          — PubSub event definitions
```

### Commands

IRC slash-command system with a clean `Handler` behaviour contract.

```
Commands
├── Parser          — Splits "/command args" from plain messages
├── Dispatcher      — Routes command name → handler module
├── Registry        — Command lookup table
├── Policy          — Permission checks before execution
├── Handler         — @behaviour: execute/2, validate/1, help/0
└── Handlers/
    ├── Join        /join #channel [key]
    ├── Part        /part [#channel] [reason]
    ├── Msg         /msg <nick> <message>
    ├── Query       /query <nick>
    ├── Me          /me <action>
    ├── Nick        /nick <newnick>
    ├── Topic       /topic [new topic]
    ├── Away        /away [message]
    ├── Whois       /whois <nick>
    ├── Kick        /kick <nick> [reason]
    ├── Ban         /ban <nick> [reason]
    ├── Mode        /mode <+/-flags> [params]
    ├── Help        /help [command]
    ├── Clear       /clear
    ├── Quit        /quit [reason]
    ├── List        /list
    ├── Ns          /ns <register|identify|ghost|info|drop> [args]
    └── Cs          /cs <register|drop|info|sop|aop|vop> [args]
```

### Services

Bot-like services that manage persistent registrations.

```
Services
├── NickServ (GenServer)
│   ├── register/2      — Register nickname with bcrypt-hashed password
│   ├── identify/2      — Authenticate to registered nickname
│   ├── ghost/2         — Disconnect stale sessions
│   ├── info/1          — View registration details
│   └── drop/2          — Unregister nickname
│
├── ChanServ (GenServer)
│   ├── register/2      — Register channel (founder becomes SOP)
│   ├── drop/1          — Unregister channel (cascades bans/access)
│   ├── info/1          — View channel registration details
│   └── access lists    — sop/aop/vop add/del/list
│
├── RegisteredNick      — Ecto schema
├── RegisteredChannel   — Ecto schema
├── AccessListEntry     — Ecto schema
├── Ban                 — Ecto schema
└── Queries             — DB operations
```

### Presence

Real-time user tracking using Phoenix.Presence (backed by distributed CRDT).

```
Presence
└── Tracker         — track/untrack/list/update_away per channel
```

### RateLimit

Flood control using an ETS table owned by a dedicated GenServer.

```
RateLimit
├── Limiter         — check_rate/2, mute enforcement, configurable thresholds
└── Table           — GenServer that owns the ETS table
```

---

## Command System

Every slash command implements the `Handler` behaviour:

```elixir
@callback execute(args :: [String.t()], context :: context()) :: result()
@callback validate(raw_args :: String.t()) :: :ok | {:error, String.t()}
@callback help() :: %{name: String.t(), syntax: String.t(), description: String.t(), examples: [String.t()]}
```

### Available Commands

| Command | Syntax | Description |
|---------|--------|-------------|
| `/join` | `/join #channel [key]` | Join a channel |
| `/part` | `/part [#channel] [reason]` | Leave a channel |
| `/msg` | `/msg <nick> <message>` | Send a private message |
| `/query` | `/query <nick>` | Open a PM conversation |
| `/me` | `/me <action>` | Send an action message |
| `/nick` | `/nick <newnick>` | Change your nickname |
| `/topic` | `/topic [new topic]` | View or set channel topic |
| `/away` | `/away [message]` | Toggle away status |
| `/whois` | `/whois <nick>` | View user information |
| `/kick` | `/kick <nick> [reason]` | Kick a user (operators only) |
| `/ban` | `/ban <nick> [reason]` | Ban a user (operators only) |
| `/mode` | `/mode <+/-flags> [params]` | Set channel modes (operators only) |
| `/help` | `/help [command]` | Show help for commands |
| `/clear` | `/clear` | Clear chat display |
| `/quit` | `/quit [reason]` | Disconnect from chat |
| `/list` | `/list` | Browse active channels |
| `/ns` | `/ns <subcommand> [args]` | NickServ operations |
| `/cs` | `/cs <subcommand> [args]` | ChanServ operations |

---

## UI Components

The interface is built with 15 function components rendering semantic HTML styled by 98.css and a custom dark theme.

### Screen Flow

```
┌──────────────────────────────────────────┐
│  ConnectLive (/)                         │
│  ┌────────────────────────────────────┐  │
│  │  ╔══════════════════════════════╗  │  │
│  │  ║  RetroHexChat - Connect      ║  │  │
│  │  ╠══════════════════════════════╣  │  │
│  │  ║                              ║  │  │
│  │  ║  Nickname: [____________]    ║  │  │
│  │  ║                              ║  │  │
│  │  ║       [ Connect ]            ║  │  │
│  │  ║                              ║  │  │
│  │  ╚══════════════════════════════╝  │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────────────────┐
│  ChatLive (/chat)                                                │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  File  Edit  View  Help                          [—][□][×] │  │
│  ├────────────────────────────────────────────────────────────┤  │
│  │  [Disconnect] [Channel List] [Away]                        │  │
│  ├──────────┬─────────────────────────────────┬───────────────┤  │
│  │ Channels │  #lobby — Welcome to the lobby  │  @CoolOp     │  │
│  │          │─────────────────────────────────│  +VoicedNick  │  │
│  │ ▾ Chans  │  [12:00] * User joined #lobby  │   RegularGuy  │  │
│  │   #lobby │  [12:01] <Alice> Hello!         │   AnotherOne  │  │
│  │   #help  │  [12:02] <Bob> Hey Alice!       │               │  │
│  │          │  [12:03] * Alice sets topic...  │               │  │
│  │ ▾ PMs    │                                 │               │  │
│  │   Alice  │                                 │               │  │
│  │          │                                 │               │  │
│  │          ├─────────────────────────────────┤               │  │
│  │          │  [____________________________] │               │  │
│  ├──────────┴─────────────────────────────────┴───────────────┤  │
│  │  Nick: Bob | #lobby | Users: 4        | Connected 00:15:32 │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────────────────┐
│  ChannelListLive (/channels)                                     │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  Search: [___________]                                     │  │
│  │                                                            │  │
│  │  Channel     │ Users │ Topic                               │  │
│  │  ────────────┼───────┼──────────────────────               │  │
│  │  #lobby      │  12   │ Welcome to RetroHexChat             │  │
│  │  #help       │   3   │ Ask your questions here             │  │
│  │  #random     │   7   │ Off-topic discussions               │  │
│  │                                                            │  │
│  │  [ Join Selected ]   [ Back to Chat ]                      │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

### Component Hierarchy

```
ChatLive
├── Window
│   ├── TitleBar            — "RetroHexChat" + window controls
│   ├── MenuBar             — File / Edit / View / Help dropdowns
│   ├── Toolbar             — Disconnect, Channel List, Away buttons
│   └── MDI Layout
│       ├── Treebar         — Channel tree + PM list + unread badges
│       ├── Chat Area
│       │   ├── Topic Bar
│       │   ├── SearchBar   — Ctrl+F search with prev/next navigation
│       │   ├── Messages    — LiveView stream of ChatMessage components
│       │   │   └── ChatMessage — Timestamp + author + content (typed)
│       │   └── Input       — Message input + history + tab-complete
│       └── Nicklist        — Users grouped: @operators, +voiced, regular
├── StatusBar               — Nickname, channel, user count, connection time
├── CommandPalette          — Ctrl+/ overlay with all slash commands
├── ContextMenu             — Right-click: Query, Whois, Kick, Ban, Op, Voice
└── Dialog                  — Modal dialogs (About, etc.)
```

### JavaScript Hooks (Minimal)

Only 4 hooks — all UI logic lives in the server via LiveView:

| Hook | Purpose |
|------|---------|
| `ScrollHook` | Infinite scroll, auto-scroll to bottom, preserve position on prepend |
| `CommandPaletteHook` | `Ctrl+/` trigger, focus management |
| `KeyboardHook` | `↑`/`↓` history, `Tab` nick completion |
| `SoundHook` | Web Audio API notification beeps |

---

## Database Schema

```
┌──────────────────────┐     ┌──────────────────────────┐
│     messages          │     │    private_messages       │
├──────────────────────┤     ├──────────────────────────┤
│ id (bigserial)       │     │ id (bigserial)           │
│ channel_name (text)  │     │ sender_nickname (text)   │
│ author_nickname (text)│     │ recipient_nickname (text)│
│ content (text)       │     │ content (text)           │
│ type (text)          │     │ type (text)              │
│ inserted_at (utc)    │     │ inserted_at (utc)        │
├──────────────────────┤     └──────────────────────────┘
│ idx: (channel, time) │
│ idx: GIN pg_trgm     │
└──────────────────────┘

┌──────────────────────────┐     ┌──────────────────────────┐
│   registered_nicks        │     │   registered_channels     │
├──────────────────────────┤     ├──────────────────────────┤
│ id (bigserial)           │     │ id (bigserial)           │
│ nickname (text, unique)  │     │ name (text, unique)      │
│ password_hash (text)     │     │ founder_nickname (text)  │
│ registered_at (utc)      │     │ topic (text)             │
│ last_seen_at (utc)       │     │ modes (text)             │
└──────────────────────────┘     │ mode_key (text)          │
                                 │ mode_limit (integer)     │
                                 │ registered_at (utc)      │
                                 └────────────┬─────────────┘
                                              │ 1:N
                           ┌──────────────────▼──────────────────┐
                           │      access_list_entries             │
                           ├─────────────────────────────────────┤
                           │ id (bigserial)                      │
                           │ channel_name (text, FK)             │
                           │ nickname (text)                     │
                           │ level (text: founder/sop/aop/vop)   │
                           │ granted_by (text)                   │
                           │ granted_at (utc)                    │
                           └─────────────────────────────────────┘

                           ┌─────────────────────────────────────┐
                           │            bans                      │
                           ├─────────────────────────────────────┤
                           │ id (bigserial)                      │
                           │ channel_name (text, FK)             │
                           │ banned_nickname (text)              │
                           │ banned_by (text)                    │
                           │ reason (text)                       │
                           │ inserted_at (utc)                   │
                           └─────────────────────────────────────┘
```

7 migrations total, including `pg_trgm` extension enablement for full-text search.

---

## Getting Started

### Prerequisites

- **Elixir** >= 1.17
- **Erlang/OTP** >= 27
- **PostgreSQL** >= 16
- **Node.js** (for 98.css npm package in assets)
- **Docker** (optional — for running PostgreSQL via Docker Compose)

### Setup

```bash
# Clone the repository
git clone https://github.com/rodrigomarchi/retro_hex_chat.git
cd retro_hex_chat

# One-command setup (starts Docker, installs deps, creates DB)
make setup

# Start the development server
make server
```

Or step by step:

```bash
# Start PostgreSQL containers (dev + test)
make docker.up

# Install dependencies
make deps
npm install --prefix apps/retro_hex_chat_web/assets

# Create and migrate the database
make db.setup

# Start the development server
make server
```

Visit [`http://localhost:4000`](http://localhost:4000) — enter a nickname and start chatting.

Run `make help` to see all available commands.

### Environment Variables (optional)

| Variable | Default | Description |
|----------|---------|-------------|
| `PGUSER` | `postgres` | PostgreSQL username |
| `PGPASSWORD` | `postgres` | PostgreSQL password |
| `PGHOST` | `localhost` | PostgreSQL host |
| `PGPORT` | `5432` | PostgreSQL port |
| `PGDATABASE` | `retro_hex_chat_dev` | Database name |

---

## Running Tests

The project follows a strict test pyramid with unit, integration, LiveView, and E2E layers.

```bash
# Full test suite (excludes E2E by default)
make test

# By layer
make test.unit            # Pure functions, validations, policies
make test.integration     # Database, GenServer, PubSub
make test.liveview        # LiveView rendering, interactions
make test.e2e             # Full screen flows (excluded from default run)

# By app
make test.domain          # Domain app only
make test.web             # Web app only

# All tests including E2E
make test.all

# Coverage report
make test.cover
```

### Test Tags

| Tag | Scope |
|-----|-------|
| `@tag :unit` | Pure functions, validations, policies |
| `@tag :integration` | Database, GenServer, PubSub |
| `@tag :liveview` | LiveView rendering, interactions |
| `@tag :e2e` | Full screen flows |

### Coverage Thresholds

| App | Threshold |
|-----|-----------|
| Domain (`retro_hex_chat`) | 80% |
| Web (`retro_hex_chat_web`) | 70% |

---

## Static Analysis

All three gates must pass before any change is merged:

```bash
# Run all static analysis checks at once
make lint

# Or individually
make format.check         # Code formatting
make credo                # Linting (strict mode, zero warnings)
make dialyzer             # Type checking (@spec on all public functions)

# Full pre-commit pipeline (compile + format + test)
make precommit
```

---

## Design Principles

This project is governed by a [Constitution](.specify/memory/constitution.md) — 10 non-negotiable principles ratified at project inception:

| # | Principle | Summary |
|---|-----------|---------|
| I | **Elixir & Phoenix Exclusive** | No JS frameworks. LiveView only. PostgreSQL only. |
| II | **Umbrella with Bounded Contexts** | 7 contexts, strict domain/web separation |
| III | **OTP Process Architecture** | GenServer per channel, DynamicSupervisor, Registry |
| IV | **TDD (Non-Negotiable)** | Tests first. Full pyramid. Suite < 60s. |
| V | **Contracts & Behaviours** | `@callback` contracts. One module per command. |
| VI | **Static Analysis from Day One** | Credo + Dialyxir + `mix format` enforced from first commit |
| VII | **Lean LiveViews** | Zero business logic in web layer. Streams for performance. |
| VIII | **Windows 98 Design Fidelity** | 98.css, dark theme, 3D bevels, monospace fonts |
| IX | **Hot/Cold Data Separation** | GenServer/ETS for runtime. PostgreSQL for persistence. |
| X | **Scalable Architecture** | Process-per-channel scales via distributed Erlang |

### Development Workflow

```
Spec → Tests (red) → Implementation (green) → Refactor → Static Analysis → Review
```

Quality gates enforced on every change:

1. `mix format --check-formatted` — no unformatted code
2. `mix credo --strict` — no lint violations
3. `mix dialyzer` — no typespec violations
4. `mix test` — all green, under 60 seconds

---

## License

This project is for educational and portfolio purposes.
