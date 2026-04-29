# RetroHexChat

> A real IRC client for the web, wearing a faithful 2000s skin — with DOOM running inside.

[![Elixir](https://img.shields.io/badge/Elixir-1.17+-4B275F?logo=elixir)](https://elixir-lang.org)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.8-FF6F00?logo=phoenix)](https://phoenixframework.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

RetroHexChat is a **fully-featured IRC client built with Elixir + Phoenix LiveView**, styled after classic mIRC and the Windows 98 desktop era. Not ironically. Just faithfully.

It has 65 slash commands, multi-user presence, NickServ/ChanServ services, P2P voice calls via an embedded TURN server, and 24+ classic games (DOOM, Quake, Wolfenstein) running via WASM — all inside a single chat interface with zero JavaScript frameworks.

---

## What makes this different

**It's a real application, not a demo.**
Full channel modes, persistent bans, role hierarchy (Owner / Op / Half-op / Voiced), ban exceptions, invite exceptions, flood control, NickServ registration with 60-second enforce timers. The kind of feature depth that takes years of IRC client usage to even know exists.

**The retro design is the primary design.**
3D bevels, blue gradient title bars, monospace fonts, MDI layout, beveled dialogs with OK/Cancel/Apply. Not an accent. Not a theme option. The entire UI was built around this aesthetic from the first commit.

**The arcade is real.**
You can open a game window inside the chat and play DOOM: Knee-Deep in the Dead, Quake, Wolfenstein 3D, or 20+ other classic games via WebAssembly engines without leaving the app. Two users can invite each other to a multiplayer game session via P2P WebRTC.

**The architecture is production-grade.**
Each IRC channel runs as an isolated OTP GenServer. If one crashes, others are unaffected. Message history uses cursor-based pagination with GIN trigram indexes for full-text search. 706 JavaScript tests. 9-check parallel CI pipeline at ~64s. Zero ignored Credo warnings. All public functions spec'd with Dialyzer.

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

- **Command palette** — `Ctrl+/` to browse all 65 slash commands with descriptions
- **Nick completion** — `Tab` autocomplete in message input
- **Message history** — `↑`/`↓` to navigate previous messages
- **Context menu** — Right-click users: Query, Whois, Kick, Ban, Op, Voice, Ignore, Nick Color, Contacts
- **Help system** — CHM-style dialog with Contents / Index / Search tabs, `F1` shortcut, 179 topics
- **Options dialog** — 6-panel preferences: Display | Chat | Sound | Log | Privacy | Advanced
- **Favorites** — Bookmark channels/PMs with encrypted passwords
- **Log viewer** — Search, filter, and export history as TXT or HTML
- **Multi-line paste** — Safe dialog for bulk text input

### P2P (WebRTC + Embedded TURN Server)

- **Voice/video calls** — Direct peer-to-peer, automatic relay via embedded TURN server
- **File transfer** — Send files between users via WebRTC DataChannel
- **250 concurrent sessions** — Ephemeral port pool (49152–49651 UDP)
- **Mutual consent** — Both users must accept before any session begins
- **ICE fallback** — Google STUN if TURN not configured

### Arcade (Single-player + Multiplayer)

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

**Quake engine (Qwasm)** — Quake Episode 1 + 8 variants and custom maps

**Other** — Wolfenstein 3D, Half-Life, ScummVM classic point-and-click adventures

**Multiplayer game sessions** — Invite another user via P2P, choose a game, play in a shared WASM canvas over WebRTC DataChannel. Bilateral accept flow, time-limited tokens, spectator support.

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
│  │ Sessions │ │ Messages │ │ Server   │ │ 65 handlers│  │
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

### Available Commands

```bash
make help           # all available targets
make setup          # first-time setup
make server         # dev server at localhost:4000
make test           # full test suite (excludes E2E)
make test.all       # full suite including E2E
make ci             # all 9 CI checks in parallel (~64s)
make ci.quick       # CI without dialyzer (faster iteration)
make lint           # format + credo + dialyzer + JS lint
make lint.js.fix    # auto-fix ESLint + Prettier issues
make precommit      # compile + format + test
```

### CI Pipeline

9 checks run in parallel across 2 stages:

```
Stage 1 (parallel):       Stage 2 (parallel, after compile):
  ├── compile               ├── format check
  ├── JS lint               ├── credo --strict
  └── JS tests              ├── CSS lint
                            ├── mix test (unit + integration + liveview)
                            ├── mix test --only e2e
                            └── dialyzer
```

~64s parallel vs ~104s serial — 38% faster.

---

## Production Deployment

RetroHexChat runs on two environments (`Sun` for production, `Moon` for staging). The deploy pipeline runs CI first, then deploys both in parallel.

```bash
make deploy         # CI + deploy both environments
make deploy.sun     # CI + deploy production only
make deploy.moon    # CI + deploy staging only
make deploy.skip-ci # deploy without CI (use only if CI was just run)
```

### Required Environment Variables

```bash
SECRET_KEY_BASE=     # mix phx.gen.secret
DATABASE_URL=        # postgresql://user:pass@host/dbname
TURN_SECRET=         # 64-byte random string for TURN auth
TURN_NONCE_SECRET=   # 64-byte random string for nonce signing
SUN_IP=              # production server IP
MOON_IP=             # staging server IP
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
│   │   │   ├── commands/            # Parser, dispatcher, 65 handlers
│   │   │   ├── p2p/                 # WebRTC signaling, TURN credentials
│   │   │   ├── presence/            # Phoenix.Presence tracker
│   │   │   ├── rate_limit/          # ETS-backed flood control
│   │   │   └── services/            # NickServ + ChanServ
│   │   └── priv/repo/migrations/    # 39 migrations
│   │
│   └── retro_hex_chat_web/          # Web (Phoenix + LiveView)
│       ├── lib/retro_hex_chat_web/
│       │   ├── live/v2/             # ConnectLive, ChatLive, P2PSessionLive
│       │   └── components/          # 57 function components, icons, dialogs
│       └── assets/
│           ├── css/                 # retrohex.css + component styles
│           └── js/hooks/            # 31 LiveView hooks
│
├── config/                          # dev / test / prod / runtime configs
├── scripts/                         # ci.exs, deploy_all.exs
└── .specify/memory/constitution.md  # 11 governing principles
```

---

## Design Principles

This project follows 11 governing principles documented in `.specify/memory/constitution.md`. The non-negotiables:

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
