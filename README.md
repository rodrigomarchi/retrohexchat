# RetroHexChat

> A real IRC client for the web, wearing a faithful 2000s skin — with DOOM running inside.

[![Elixir](https://img.shields.io/badge/Elixir-1.17+-4B275F?logo=elixir)](https://elixir-lang.org)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.8-FF6F00?logo=phoenix)](https://phoenixframework.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

RetroHexChat is a **fully-featured IRC client built with Elixir + Phoenix LiveView**, styled after classic mIRC and the Windows 98 desktop era. Not ironically. Just faithfully.

It has 54 slash commands, multi-user presence, NickServ/ChanServ services, virtual Spaces, private P2P calls and files, channel conferences via a self-hosted SFU, 34 multiplayer games, and 18 classic single-player games running via WASM — all inside a single chat interface with zero JavaScript frameworks.

---

## What makes this different

**It's a real application, not a demo.**
Full channel modes, persistent bans, role hierarchy (Owner / Op / Half-op / Voiced), ban exceptions, invite exceptions, flood control, NickServ registration with 60-second enforce timers. The kind of feature depth that takes years of IRC client usage to even know exists.

**The retro design is the primary design.**
3D bevels, blue gradient title bars, monospace fonts, MDI layout, beveled dialogs with OK/Cancel/Apply. Not an accent. Not a theme option. The entire UI was built around this aesthetic from the first commit.

**The arcade is real.**
You can open a game window inside the chat and play DOOM: Knee-Deep in the Dead, Quake, Quake II, Wolfenstein 3D, Half-Life: Uplink, or ScummVM adventures via WebAssembly engines without leaving the app. Two users can also invite each other to one of 34 multiplayer game sessions via P2P WebRTC.

**The architecture is production-grade.**
Each IRC channel runs as an isolated OTP GenServer. If one crashes, others are unaffected. Message history uses cursor-based pagination with GIN trigram indexes for full-text search. 706 JavaScript tests. 13-check partitioned local CI guard. Zero ignored Credo warnings. All public functions spec'd with Dialyzer.

---

## Features

### Chat

- **Multi-channel** — MDI layout: TreeBar sidebar + tabs + topic bar + chat area + nicklist
- **Private messages** — `/msg`, `/query`, with PM typing indicators
- **Message history** — Persistent, cursor-paginated infinite scroll
- **Full-text search** — PostgreSQL trigram search across all history (`Ctrl+F`)
- **Action messages** — `/me` with italic formatting
- **mIRC color codes** — 16 foreground/background colors with `Ctrl+K` picker
- **Rich text** — Bold (`Ctrl+B`), italic (`Ctrl+I`), underline (`Ctrl+U`), reverse (`Ctrl+R`)
- **Formatting toolbar** — SVG buttons + 4×4 color grid dropdown
- **Emoji picker** — 300+ emojis organized by category
- **Unread indicators** — Badges on channels, TreeBar flash for highlights

### Channels

- **Channel modes** — `+i` (invite-only), `+m` (moderated), `+t` (topic lock), `+k` (key), `+l` (user limit), `+e` (ban exceptions), `+I` (invite exceptions)
- **Roles** — Owner (`~`), Operators (`@`), Half-ops (`%`), Voiced (`+`)
- **Channel Central** — 5-tab management dialog: General | Modes | Bans | Ban Exceptions | Invite Exceptions
- **Channel list** — Browse active channels with filtering and search
- **Advanced** — Join throttle, `/knock` for invite-only channels, 7 additional modes

### Services

- **NickServ** — Register nicknames, identify, ghost stale sessions, 60-second enforce timer
- **ChanServ** — Register channels with Founder → SOP → AOP → VOP access list hierarchy

### Buddy List & Contacts

- **Notify list** — Track friends online/away with 10-second debounce, auto-rotate when list is full
- **Address Book** — 4-tab dialog: Contacts | Notify | Nick Colors | Control
- **Per-user nick colors** — Override colors in chat, nicklist, and notify list
- **Ignore system** — Per-type (messages/PMs/invites/actions), timed expiry, persistent storage

### Moderation & Flood Control

- **Kick/Ban** — Persistent bans stored in PostgreSQL with reasons
- **Flood protection** — ETS-backed rate limiting, duplicate detection, auto-ignore, mute enforcement
- **Ban exceptions** (`+e`) and **invite exceptions** (`+I`) for fine-grained control

### Automation

- **Perform** — Auto-execute commands on connect (NickServ identify, channel joins)
- **Auto-join** — Join channels on connect with optional channel keys
- **Aliases** — Custom commands with `$1`–`$9` variable expansion
- **Timers** — Recurring or one-shot command execution
- **Auto-respond** — Pattern-matched automatic replies
- **Auto-reconnect** — Exponential backoff (1–30s) with retro overlay

### User Information

- **Whois** — Idle time, channels, registration status, bio
- **Whowas** — ETS-cached history of recently disconnected users
- **Real-time presence** — Online/away tracking across all channels

### URL & Link Management

- **URL Catcher** — Dedicated window with sort, filter, and search across all links
- **Link previews** — Async fetch with ETS cache (1h for success, 5min for errors)
- **Long URL truncation** — Display-friendly with full URL on click

### UI & Keyboard

- **Command palette** — `Ctrl+/` to browse all 54 slash commands with descriptions
- **Nick completion** — `Tab` autocomplete in message input
- **Message history** — `↑`/`↓` to navigate previous messages
- **Context menu** — Right-click users: Query, Whois, Kick, Ban, Op, Voice, Ignore, Nick Color, Contacts
- **Help system** — CHM-style dialog with Contents / Index / Search tabs, `F1` shortcut, 179 topics
- **Options dialog** — 6-panel preferences: Display | Chat | Sound | Log | Privacy | Advanced
- **Favorites** — Bookmark channels/PMs with encrypted passwords
- **Log viewer** — Search, filter, and export history as TXT or HTML
- **Multi-line paste** — Safe dialog for bulk text input

### Private P2P (WebRTC + Embedded TURN Server)

- **Voice/video calls** — Private peer-to-peer sessions, automatic relay via embedded TURN server
- **File transfer** — Send files between users via WebRTC DataChannel
- **250 concurrent sessions** — Ephemeral port pool (49152–49651 UDP)
- **Mutual consent** — Both users must accept before any session begins
- **ICE fallback** — Google STUN if TURN not configured

### Spaces & Channel Conferences

- **Virtual Spaces** — Switch any channel or DM from Chat to Space and walk the same conversation as an avatar on a shared 8-bit map
- **Server-validated movement** — The browser sends inputs; the server validates movement, collision, seating, and interactions before broadcasting deltas
- **Channel conferences** — Group audio/video calls live inside channels with pre-join devices, screen sharing, reactions, hand raise, layouts, and moderator controls
- **Self-hosted SFU** — Private calls are P2P, while channel conferences route media through your own server so group calls remain practical

### Arcade (18 Single-player + 34 Multiplayer)

Single-player games run via WebAssembly engines directly in the browser. No installs, no plugins.

**DOOM engine (Dwasm)**

| Game | Description |
|------|-------------|
| DOOM: Knee-Deep in the Dead | Original Episode 1 shareware (9 levels) |
| Freedoom Phase 1 | Open-source DOOM (4 episodes, 36 levels) |
| Freedoom Phase 2 | DOOM II compatible (32 levels) |
| FreeDM | 32 deathmatch arenas |
| Chex Quest | 1996 cereal box promotion, 5 levels |
| HacX: Twitch 'n Kill | Cyberpunk total conversion |
| REKKR: Sunken Land | Viking-themed, hand-drawn art style |

**Quake engines** — Quake shareware, LibreQuake, and Quake II shareware

**Other** — Wolfenstein 3D, Half-Life: Uplink, and ScummVM classic point-and-click adventures

**Multiplayer game sessions** — Invite another user via P2P, choose from 34 two-player games, and sync gameplay over WebRTC DataChannel. Bilateral accept flow and time-limited tokens.

---

## Architecture

RetroHexChat is a **Phoenix umbrella application** with strict compile-time separation between domain logic and web concerns. The `retro_hex_chat` app has zero Phoenix dependencies.

```
┌──────────────────────────────────────────────────────────┐
│                     Browser (LiveView)                    │
│  ConnectLive ──→ ChatLive ──→ ChannelListLive            │
│  57 function components · 31 JS hooks · retro CSS        │
└──────────────────────┬───────────────────────────────────┘
                       │ Phoenix.PubSub
┌──────────────────────▼───────────────────────────────────┐
│              retro_hex_chat (Domain Layer)                │
│                                                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐  │
│  │ Accounts │ │   Chat   │ │ Channels │ │  Commands  │  │
│  │ Sessions │ │ Messages │ │ Server   │ │ 54 handlers│  │
│  │ NickValid│ │ History  │ │ Modes    │ │ Parser     │  │
│  └──────────┘ └──────────┘ └──────────┘ └────────────┘  │
│                                                          │
│  ┌──────────┐ ┌──────────┐ ┌───────────┐ ┌──────────┐   │
│  │ Services │ │ Presence │ │ RateLimit │ │   P2P    │   │
│  │ NickServ │ │ Tracker  │ │ Limiter   │ │ TURN/STUN│   │
│  │ ChanServ │ │(Phoenix) │ │ (ETS)     │ │ Signaling│   │
│  └──────────┘ └──────────┘ └───────────┘ └──────────┘   │
└──────────────────────┬───────────────────────────────────┘
                       │
         ┌─────────────▼──────────────┐
         │       PostgreSQL 16+       │
         │  39 migrations · 36 schemas│
         │  GIN trigram indexes       │
         └────────────────────────────┘
```

### OTP Supervision Tree

Every channel is an isolated OTP process. If one crashes, others are unaffected.

```
RetroHexChat.Supervisor (:one_for_one)
│
├── Repo                         Ecto database connection pool
├── Phoenix.PubSub               Message broadcast backbone
│     topics: "channel:#{name}" · "user:#{nick}" · "pm:#{ids}" · "game:#{token}"
│
├── Registry (ChannelRegistry)   Named process lookup
├── Channels.Supervisor          DynamicSupervisor — spawns/terminates on demand
│     ├── Channels.Server "#lobby"     ← GenServer: topic, modes, bans, members
│     ├── Channels.Server "#general"
│     └── Channels.Server "#random"    transient: empty channels stop gracefully
│
├── Presence.Tracker             Phoenix.Presence — distributed user tracking
├── RateLimit.Table              GenServer owning ETS flood-control counters
├── Services.NickServ            Registration, identify, ghost, enforce timer
├── Services.ChanServ            Channel registration, access lists
├── Chat.LinkPreview.Cache       GenServer + ETS — URL metadata cache
└── Task.Supervisor              Async HTTP fetches for link previews
```

### Hot/Cold Data Separation

| Layer | Storage | What lives here |
|-------|---------|-----------------|
| Hot | GenServer (per channel) | Topic, modes, bans, membership — sub-millisecond reads |
| Hot | ETS | Rate-limit counters, mute state, link preview cache, whowas |
| Hot | Phoenix.Presence | Online/away users per channel, real-time |
| Hot | Socket assigns | Session state, pending invites, timers, idle time |
| Cold | PostgreSQL | Messages, registrations, preferences, favorites, user data |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Elixir 1.17+ / OTP 27+ |
| Framework | Phoenix 1.8 + LiveView 1.0+ |
| Database | PostgreSQL 16+ (GIN/trigram indexes, cursor pagination) |
| WebRTC | ExSTUN ~> 0.1 (embedded TURN/STUN server) |
| HTTP Client | Req 0.5+ (async link previews via Task.Supervisor) |
| Auth | bcrypt\_elixir (passwords), Plug.Crypto (favorites encryption) |
| Observability | PromEx `/metrics` for Prometheus, with core Ecto metrics captured before `Repo` startup, plus OpenTelemetry OTLP traces for Tempo |
| Assets | esbuild + Tailwind CSS |
| JS Testing | Vitest + jsdom (706 tests, 62 files) |
| Static Analysis | Credo (strict), Dialyxir, mix format, ESLint + Prettier |
| Testing | ExUnit, Mox, ExMachina, StreamData, Floki, Playwright (E2E) |

---

## Getting Started

### Requirements

- Elixir 1.17+ / OTP 27+
- PostgreSQL 16+
- Node.js 20+
- Docker (optional, for the database)

### Setup

```bash
git clone https://github.com/rodrigomarchi/retro_hex_chat.git
cd retro_hex_chat

# Generate a dev secret key
mix phx.gen.secret
# Paste the output into config/dev.exs as secret_key_base

make setup   # deps + database + migrations
make server  # starts at http://localhost:4000
```

Before any direct commit or push to `main`, check the remote and pull first:

```bash
git fetch origin
git status --short --branch
git pull --ff-only origin main
```

### Available Commands

```bash
make help           # all available targets
make setup          # first-time setup
make server         # dev server at localhost:4000
make test           # full test suite (excludes E2E)
make test.all       # ExUnit suite including LiveView feature tests
make ci             # complete local guard, partitioned ExUnit suites
make ci.quick       # CI without dialyzer (faster iteration)
make ci.changed     # checks selected from git diff; use EXPLAIN=1 to inspect
make ci.serial      # same full guard with one ExUnit partition per suite
make ci.partition-profile # measure ExUnit partition counts
make test.stale     # local stale ExUnit loop
make test.js.changed # local Vitest changed loop
make lint.js.changed # local ESLint/Prettier changed loop
make e2e.smoke SURFACE=connect # focused Playwright smoke
make lint           # format + credo + dialyzer + JS lint
make lint.js.fix    # auto-fix ESLint + Prettier issues
make precommit      # compile + format + test
```

### CI Pipeline

The complete local guard runs 13 checks across staged parallel groups. ExUnit suites are
partitioned by default with `CI_TEST_PARTITIONS=3`, `CI_FEATURE_PARTITIONS=4`, and
`CI_TEST_DB_POOL_SIZE=6`; set both partition counts to `1` or use `make ci.serial`
to diagnose partition-specific issues.

```
Stage 1 (parallel):
  ├── compile
  ├── JS lint
  ├── JS tests
  ├── CI impact tests
  ├── CI partition profile plan
  ├── i18n tooling tests
  └── i18n quality

Stage 2 (parallel, after compile):
  ├── format check
  ├── credo --strict
  ├── CSS lint + strict style audit
  ├── mix test (partitioned)
  └── mix test --only liveview_feature (partitioned)

Browser smokes (ci.changed only when selected):
  ├── connect
  ├── chat shell
  ├── dialogs
  ├── i18n
  ├── P2P/group call
  └── mobile

Stage 3 (isolated):
  └── dialyzer
```

Playwright remains a deliberate local E2E suite, not part of the default `make ci`
guard. The selective guard can choose focused browser smokes for critical UI
changes: `make e2e.smoke SURFACE=connect|chat|dialogs|i18n|calls|mobile`.

Latest measured local runs: `make ci` completed 13/13 checks three times in
`2m22s`-`2m25s` with 3-way normal tests, 4-way feature tests, DB pool 6 per
partition, and a warm Dialyzer PLT. `make ci.serial` completed 13/13 in `5m28s`.

---

## Production Deployment

RetroHexChat deploys to one production server: `Sun`. The standard deploy pipeline
runs CI first, then publishes the release for DeployEx on that server.

```bash
make deploy         # CI + deploy production (Sun)
make deploy.skip-ci # deploy without CI (use only if CI was just run)
```

### Required Environment Variables

```bash
SECRET_KEY_BASE=     # mix phx.gen.secret
DATABASE_URL=        # postgresql://user:pass@host/dbname
TURN_SECRET=         # 64-byte random string for TURN auth
TURN_NONCE_SECRET=   # 64-byte random string for nonce signing
DEPLOY_USER=         # SSH user on the production server
SUN_IP=              # production server IP
SSH_PORT=2222        # SSH port, optional; defaults to 2222
```

### Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 4000 | TCP | HTTP + WebSocket |
| 3478 | UDP | TURN/STUN signaling |
| 49152–49651 | UDP | TURN relay (P2P sessions) |

---

## Project Structure

```
retro_hex_chat/
├── apps/
│   ├── retro_hex_chat/              # Domain (pure Elixir, no Phoenix deps)
│   │   ├── lib/retro_hex_chat/
│   │   │   ├── accounts/            # Sessions, nickname validation
│   │   │   ├── channels/            # GenServer per channel, modes, policy
│   │   │   ├── chat/                # Messages, history, search, highlights
│   │   │   ├── commands/            # Parser, dispatcher, 54 handlers
│   │   │   ├── p2p/                 # WebRTC signaling, TURN credentials
│   │   │   ├── presence/            # Phoenix.Presence tracker
│   │   │   ├── prom_ex.ex           # Core PromEx collector; Ecto starts before Repo
│   │   │   ├── rate_limit/          # ETS-backed flood control
│   │   │   └── services/            # NickServ + ChanServ
│   │   └── priv/repo/migrations/    # 39 migrations
│   │
│   └── retro_hex_chat_web/          # Web (Phoenix + LiveView)
│       ├── lib/retro_hex_chat_web/
│       │   ├── prom_ex.ex           # Phoenix/LiveView PromEx collector
│       │   ├── prom_ex_plug.ex      # Aggregates core + web collectors at /metrics
│       │   ├── open_telemetry.ex    # Phoenix/Bandit/Ecto tracing setup
│       │   ├── live/app/             # ConnectLive, ChatLive, P2PSessionLive
│       │   └── components/          # 57 function components, icons, dialogs
│       └── assets/
│           ├── css/                 # retrohex.css + component styles
│           └── js/hooks/            # 31 LiveView hooks
│
├── config/                          # dev / test / prod / runtime configs
├── scripts/                         # ci.exs, deploy_all.exs
└── docs/AGENT-GUIDE.md              # 11 governing principles + durable guidance
```

---

## Design Principles

This project follows 11 governing principles documented in `docs/AGENT-GUIDE.md`. The non-negotiables:

1. **TDD** — Tests come first or alongside; no retrofitting
2. **Umbrella boundaries** — Domain never imports from web layer
3. **OTP process architecture** — Per-channel process isolation, not a monolithic state
4. **Static analysis from day one** — Zero Credo warnings, all public functions @spec'd
5. **Retro design fidelity** — The aesthetic is core, not cosmetic

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup instructions and PR guidelines.

Bug reports and feature requests go in [Issues](https://github.com/rodrigomarchi/retro_hex_chat/issues).

Security vulnerabilities should be reported privately — see [SECURITY.md](SECURITY.md).

---

## License

MIT — see [LICENSE](LICENSE).
