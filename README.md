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
- [Production Deployment](#production-deployment)
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

### Text & Formatting
- **mIRC color codes** — 16 foreground/background colors with `Ctrl+K` color picker
- **Rich text** — Bold (`Ctrl+B`), italic (`Ctrl+I`), underline (`Ctrl+U`), reverse (`Ctrl+R`)
- **Formatting toolbar** — SVG icon buttons with 4x4 color picker dropdown
- **Strip formatting** — Toggle to view messages as plain text

### Channels
- **Channel modes** — `+i` (invite-only), `+m` (moderated), `+t` (topic lock), `+k` (key/password), `+l` (user limit)
- **Role system** — Owner (`~`), Operators (`@`), Half-ops (`%`), Voiced (`+`), and regular users
- **Topic management** — Set and view channel topics with permission control
- **Channel list** — Browse active channels with topic, user count, and search/filter
- **Channel Central** — 5-tab dialog (General, Modes, Bans, Ban Exceptions, Invite Exceptions)
- **Advanced modes** — 7 additional channel modes, join throttle, `/knock` for invite-only channels

### Services
- **NickServ** — Register nicknames, identify, ghost sessions, 60-second enforce timer
- **ChanServ** — Register channels, manage access lists (Founder → SOP → AOP → VOP)

### Moderation
- **Kick** — Remove users from channels with optional reason
- **Ban** — Persistent bans stored in PostgreSQL, ban exceptions (`+e`)
- **Invite exceptions** — `+I` mode to bypass invite-only restriction
- **Rate limiting** — Flood control with mute enforcement via ETS counters
- **Flood protection** — Duplicate detection, auto-ignore, CTCP rate limiting

### Buddy List & Contacts
- **Notify list** — Track friends' online/away status with 10-second debounce notifications
- **Address book** — 4-tab dialog (Contacts, Notify, Nick Colors, Control)
- **Nick colors** — Per-user color overrides in chat, nicklist, and notify list
- **Ignore system** — Per-type ignores (messages/PMs/invites/actions), timed expiry, persistent list

### Highlight & Mentions
- **Custom highlight words** — Up to 50 words with per-word color configuration
- **TreeBar flash** — Visual indicator on channels with unread highlights
- **Sound notifications** — Configurable per-event sounds with global mute toggle

### URL Handling
- **Clickable URLs** — Auto-detected with long URL truncation (>100 chars)
- **URL Catcher** — Window with sort/filter/search across all captured URLs
- **Link previews** — Async HTTP fetch with ETS cache (1h success/5min error TTL)

### Automation
- **Perform commands** — Auto-execute commands on connect (NickServ identify, join channels)
- **Auto-join** — Automatically join channels on connect with optional keys
- **Auto-reconnect** — Exponential backoff (1-30s) with Win98-style overlay
- **Aliases** — Custom commands with `$1`-`$9` variable expansion
- **Timers** — Recurring/one-shot command execution
- **Auto-respond** — Pattern-matched automatic replies

### Communication
- **Channel invites** — `/invite` with Win98 dialog, 5-minute expiry
- **Notices** — `/notice` with configurable routing (channel/status/active window)
- **CTCP** — PING/VERSION/TIME/FINGER with configurable responses
- **Special messages** — MOTD, channel welcome messages, `/wallops`, `/announce`

### User Information
- **Expanded whois** — Detailed user info with idle time, channels, registration
- **Whowas** — ETS-cached history of recently disconnected users
- **Bio** — `/bio` command for personal descriptions
- **Idle tracking** — Per-user idle time visible in whois

### Favorites & Preferences
- **Favorites** — Bookmark channels/PMs with encrypted passwords (Plug.Crypto)
- **Options dialog** — Centralized 6-panel preferences hub with real-time CSS custom properties
- **Log viewer** — Search/filter/export (TXT/HTML) with display preferences
- **Help system** — CHM-style dialog with Contents/Index/Search tabs, F1 shortcut

### UI
- **Windows 98 aesthetic** — 98.css with a custom dark theme
- **MDI layout** — TreeBar (channels/PMs) | Tab bar | Topic bar | Chat area | Nicklist
- **Context menus** — Right-click users for Query, Whois, Kick, Ban, Op, Voice, Ignore, Nick Color, Add to Contacts
- **Command palette** — `Ctrl+/` to browse all slash commands
- **Keyboard shortcuts** — `↑`/`↓` history, `Tab` completion, `Ctrl+F` search, `F1` help
- **Real-time presence** — Online/away status tracking across channels
- **Emoji picker** — 300+ emojis with category browsing
- **Character counter** — Real-time count in message input
- **Multi-line paste** — Dialog for pasting multi-line content
- **Sounds & notifications** — Per-event configurable sounds, PM typing indicator

---

## Architecture

RetroHexChat is a **Phoenix umbrella application** with strict separation between domain logic and web concerns:

```
┌─────────────────────────────────────────────────────────┐
│                    Browser (LiveView)                    │
│  ConnectLive ──→ ChatLive ──→ ChannelListLive           │
│  41 function components · 16 JS hooks · 98.css dark     │
└─────────────────────┬───────────────────────────────────┘
                      │ Phoenix.PubSub
┌─────────────────────▼───────────────────────────────────┐
│              retro_hex_chat (Domain Layer)               │
│                                                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────┐  │
│  │ Accounts │ │   Chat   │ │ Channels │ │  Commands  │  │
│  │          │ │          │ │          │ │            │  │
│  │ Sessions │ │ Messages │ │ Server   │ │ 45 Handlers│  │
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
        │  28 migrations · 29 schemas│
        │  GIN trigram indexes       │
        └────────────────────────────┘
```

### Hot/Cold Data Separation

| Layer | Storage | Data | Access Pattern |
|-------|---------|------|----------------|
| **Hot** | GenServer (per channel) | Topic, modes, bans, membership | Sub-millisecond reads |
| **Hot** | ETS | Rate-limit counters, mute state, link preview cache, whowas cache | Concurrent reads |
| **Hot** | Phoenix.Presence | Online/away users per channel | Real-time tracking |
| **Hot** | Socket assigns | Session state, pending invites, timers, idle tracking | Per-connection |
| **Cold** | PostgreSQL | Messages, registrations, preferences, favorites, user data | Cursor-based pagination |

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
| HTTP Client | **Req 0.5+** | Link preview fetching |
| Auth | **bcrypt_elixir** | Password hashing for NickServ |
| Encryption | **Plug.Crypto** | Favorites password encryption |
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
│   │   │   ├── chat/                   # Messages, history, search, formatter,
│   │   │   │                           # highlight, help topics, URL detector
│   │   │   ├── commands/               # Parser, dispatcher, 45 handlers
│   │   │   ├── presence/               # Phoenix.Presence tracker
│   │   │   ├── rate_limit/             # ETS-backed flood control
│   │   │   └── services/               # NickServ + ChanServ bots
│   │   ├── priv/repo/migrations/       # 28 database migrations
│   │   └── test/                       # Domain tests (unit + integration)
│   │
│   └── retro_hex_chat_web/             # Web app (Phoenix + LiveView)
│       ├── lib/retro_hex_chat_web/
│       │   ├── live/
│       │   │   ├── connect_live.ex      # Nickname entry screen
│       │   │   ├── chat_live.ex         # Main chat MDI screen
│       │   │   └── channel_list_live.ex # Channel browser screen
│       │   └── components/             # ~40 function components
│       │       ├── window.ex            # Win98 window chrome
│       │       ├── title_bar.ex         # Blue gradient title bar
│       │       ├── menu_bar.ex          # File/Edit/View/Help menus
│       │       ├── toolbar.ex           # Icon button toolbar
│       │       ├── tab_bar.ex           # Status/Channel/PM tabs
│       │       ├── topic_bar.ex         # Channel name+modes+topic
│       │       ├── treebar.ex           # Channel/PM tree sidebar
│       │       ├── chat_message.ex      # Message rendering (formatted)
│       │       ├── nicklist.ex          # User list (~/@ /%/+/regular)
│       │       ├── formatting_toolbar.ex # B/I/U/Color/Strip buttons
│       │       ├── status_bar.ex        # Bottom status bar
│       │       ├── command_palette.ex   # Ctrl+/ command picker
│       │       ├── context_menu.ex      # Right-click user menu
│       │       ├── search_bar.ex        # In-chat search
│       │       ├── scroll_loader.ex     # Infinite scroll loader
│       │       ├── dialog.ex            # Modal dialogs
│       │       ├── help_dialog.ex       # CHM-style help viewer
│       │       ├── options_dialog.ex    # 6-panel preferences hub
│       │       ├── address_book_dialog.ex # Contacts/Notify/Colors/Control
│       │       ├── highlight_dialog.ex  # Highlight words config
│       │       ├── ignore_list_dialog.ex # Ignore list management
│       │       ├── channel_central_dialog.ex # Channel settings (5 tabs)
│       │       ├── log_viewer_dialog.ex # Log search/export
│       │       ├── perform_dialog.ex    # Perform/Auto-join config
│       │       ├── favorites_dialog.ex  # Bookmark management
│       │       ├── notify_list_window.ex # Buddy list window
│       │       └── url_catcher_window.ex # URL capture/search
│       ├── assets/
│       │   ├── css/
│       │   │   ├── dark-theme.css       # Win98 dark theme
│       │   │   └── layout.css           # Component layout styles
│       │   └── js/hooks/               # 16 LiveView hooks
│       └── test/                        # Web tests (LiveView + E2E)
│
├── config/                              # Environment configs (dev/test/prod)
├── .specify/                            # Speckit design artifacts
│   └── memory/constitution.md           # 11 governing principles
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
│     ├── Channels.Server "#general"      (topic, modes, bans, members,
│     └── Channels.Server "#random"        ban/invite exceptions, join throttle)
│                                         Transient restart: empty
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
├── Services.ChanServ
│     GenServer — channel registration, access lists (founder/sop/aop/vop)
│
├── Chat.LinkPreview.Cache
│     GenServer + ETS — URL metadata cache (1h success/5min error TTL)
│
└── Task.Supervisor (RetroHexChat.TaskSupervisor)
      Async tasks for HTTP fetches (link previews)
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
├── Session         — In-memory user state: channels, PMs, away, preferences,
│                     notify list, contacts, nick colors, highlights, ignores,
│                     favorites, perform/autojoin, sound settings, CTCP settings
├── NicknameValidator — 1-16 chars, alphanumeric + _-[]{}^
└── Policy          — Authorization checks (can user perform action?)
```

### Chat

Handles message persistence, retrieval, search, formatting, and content analysis.

```
Chat
├── Message         — Ecto schema: channel messages (system, action, regular)
├── PrivateMessage   — Ecto schema: direct messages between users
├── Queries         — Cursor-based pagination (before_id), batch inserts
├── Service         — High-level operations: send, history, search
├── Search          — PostgreSQL pg_trgm trigram full-text search
├── Formatter       — mIRC color/bold/italic/underline parser → safe HTML
├── Highlight       — Mention detection engine (nick + custom words)
├── HelpTopics      — 90+ help topics across 8 categories
├── URLDetector     — URL extraction, linkify, HTML linkification
└── LinkPreview     — Behaviour + Cache + HTTP fetcher for URL metadata
```

### Channels

The core real-time engine. Each active channel is a GenServer process.

```
Channels
├── Server          — GenServer: topic, modes, bans, members, ban/invite exceptions,
│                     join throttle, message dispatch
├── Supervisor      — DynamicSupervisor: process lifecycle management
├── Registry        — via_tuple named process lookup
├── Membership      — Roles: :owner, :operator, :halfop, :voiced, :regular
├── Modes           — +i +m +t +k +l +e +I and 7 advanced modes
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
├── Registry        — Command lookup table (45 commands)
├── Policy          — Permission checks before execution
├── Handler         — @behaviour: execute/2, validate/1, help/0
└── Handlers/       — 45 handler modules (see Command System section)
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
├── BanException        — Ecto schema
├── InviteException     — Ecto schema
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
| `/whowas` | `/whowas <nick>` | View info on recently disconnected user |
| `/kick` | `/kick <nick> [reason]` | Kick a user (operators only) |
| `/ban` | `/ban <nick> [reason]` | Ban a user (operators only) |
| `/mode` | `/mode <+/-flags> [params]` | Set channel modes (operators only) |
| `/umode` | `/umode <+/-flags>` | Set user modes |
| `/help` | `/help [command]` | Show help for commands |
| `/clear` | `/clear` | Clear chat display |
| `/quit` | `/quit [reason]` | Disconnect from chat |
| `/list` | `/list` | Browse active channels |
| `/ns` | `/ns <subcommand> [args]` | NickServ operations |
| `/cs` | `/cs <subcommand> [args]` | ChanServ operations |
| `/ignore` | `/ignore <nick> [type] [duration]` | Ignore a user |
| `/unignore` | `/unignore <nick>` | Remove user from ignore list |
| `/notify` | `/notify <add\|remove\|edit\|list> [args]` | Manage notify list |
| `/invite` | `/invite <nick> [#channel]` | Invite user to channel |
| `/knock` | `/knock #channel [message]` | Request entry to invite-only channel |
| `/notice` | `/notice <target> <message>` | Send a notice |
| `/notice_routing` | `/notice_routing [setting]` | Configure notice display |
| `/ctcp` | `/ctcp <nick> <type>` | Send CTCP request |
| `/perform` | `/perform <add\|remove\|move\|list\|clear> [args]` | Manage perform commands |
| `/autojoin` | `/autojoin <add\|remove\|list\|clear> [args]` | Manage auto-join channels |
| `/bio` | `/bio [text]` | Set or view your bio |
| `/alias` | `/alias <name> <command>` | Create command alias |
| `/timer` | `/timer <interval> <command>` | Set recurring/one-shot timer |
| `/popups` | `/popups <add\|remove\|list>` | Manage custom popup menus |
| `/auto_respond` | `/auto_respond <add\|remove\|list>` | Manage auto-respond rules |
| `/wallops` | `/wallops <message>` | Send message to all operators |
| `/announce` | `/announce <message>` | Send global announcement |
| `/setmotd` | `/setmotd <text>` | Set Message of the Day |
| `/clearmotd` | `/clearmotd` | Clear Message of the Day |
| `/motd` | `/motd` | View Message of the Day |
| `/setwelcome` | `/setwelcome [#channel] <text>` | Set channel welcome message |
| `/clearwelcome` | `/clearwelcome [#channel]` | Clear channel welcome message |

---

## UI Components

The interface is built with ~40 function components rendering semantic HTML styled by 98.css and a custom dark theme.

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
│  │  File  Edit  View  Tools  Help                    [—][□][×] │  │
│  ├────────────────────────────────────────────────────────────┤  │
│  │  [🔌Disconnect] [📋List] [⚙Settings] [📖Book] [📝Logs]   │  │
│  ├────────────────────────────────────────────────────────────┤  │
│  │  [Status] [#lobby] [#help] [Alice ×]        ← Tab Bar     │  │
│  ├──────────┬─────────────────────────────────┬───────────────┤  │
│  │ Channels │  #lobby (+nt) — Welcome!        │  ~Owner       │  │
│  │          │─────────────────────────────────│  @CoolOp      │  │
│  │ ▾ Chans  │  [B][I][U][🎨][S]  ← Format   │  %HalfOp      │  │
│  │   #lobby │  [12:00] * User joined #lobby  │  +VoicedNick  │  │
│  │   #help  │  [12:01] <Alice> Hello!         │   RegularGuy  │  │
│  │          │  [12:02] <Bob> Hey Alice!       │               │  │
│  │ ▾ PMs    │                                 │               │  │
│  │   Alice  │                                 │               │  │
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
│   ├── MenuBar             — File / Edit / View / Tools / Help dropdowns
│   ├── Toolbar             — Disconnect, Channel List, Settings, Address Book, Logs (SVG icons)
│   ├── TabBar              — Status / Channel / PM tabs with close buttons + unread/highlight states
│   └── MDI Layout
│       ├── Treebar         — Channel tree + PM list + unread badges
│       ├── Chat Area
│       │   ├── TopicBar    — Channel name + modes + topic (or PM target / status text)
│       │   ├── FormattingToolbar — B/I/U/Color/Strip SVG buttons + color picker
│       │   ├── SearchBar   — Ctrl+F search with prev/next navigation
│       │   ├── Messages    — LiveView stream of ChatMessage components
│       │   │   └── ChatMessage — Timestamp + author + formatted content (colors, URLs, highlights)
│       │   └── Input       — Message input + history + tab-complete + emoji picker + char counter
│       └── Nicklist        — Users grouped: ~owner, @operators, %halfops, +voiced, regular
├── StatusBar               — Nickname, channel, user count, connection time
├── CommandPalette          — Ctrl+/ overlay with all slash commands
├── ContextMenu             — Right-click: Query, Whois, Kick, Ban, Op, Voice, Ignore, Nick Color, Contacts
├── HelpDialog              — F1: CHM-style viewer (Contents/Index/Search tabs)
├── OptionsDialog           — 6-panel centralized preferences hub
├── AddressBookDialog       — Contacts / Notify / Nick Colors / Control tabs
├── HighlightDialog         — Custom highlight words + 16-color picker
├── IgnoreListDialog        — Ignore list management with add/remove
├── ChannelCentralDialog    — General / Modes / Bans / Ban Exceptions / Invite Exceptions
├── LogViewerDialog         — Log search/filter/export (TXT/HTML)
├── PerformDialog           — Perform commands / Auto-join management
├── FavoritesDialog         — Bookmark management with encrypted passwords
├── NotifyListWindow        — Buddy list with presence status
└── URLCatcherWindow        — Captured URL list with sort/filter/search
```

### JavaScript Hooks

16 hooks — all core UI logic lives in the server via LiveView:

| Hook | Purpose |
|------|---------|
| `ScrollHook` | Infinite scroll, auto-scroll to bottom, preserve position on prepend, link preview injection |
| `CommandPaletteHook` | `Ctrl+/` trigger, focus management |
| `KeyboardHook` | `↑`/`↓` history, `Tab` nick completion, keyboard shortcuts |
| `SoundHook` | Web Audio API notification sounds, per-event configuration |
| `FormatToolbarHook` | Formatting toolbar interactions, color picker, insert format codes |
| `NotifyListHook` | Double-click to open PM from buddy list |
| `URLCatcherHook` | Double-click to open URL in new tab |
| `DownloadHook` | Base64 decode + Blob download for log exports |
| `ReconnectHook` | Auto-reconnect overlay, exponential backoff, session restore |
| `EmojiPickerHook` | Emoji category browsing and insertion |
| `PasteDialogHook` | Multi-line paste detection and dialog |
| `CharCounterHook` | Real-time character count in input |
| `ContextMenuHook` | Right-click menu positioning |
| `ColorPickerHook` | Nick color picker interactions |
| `TimerHook` | Client-side timer display updates |
| `DragHook` | Dialog window dragging |

---

## Database Schema

28 migrations, 29 Ecto schemas. Core tables:

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
                                 │ mode_join_throttle (int) │
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
```

### Additional Tables

| Table | Feature | Key Columns |
|-------|---------|-------------|
| `bans` | Moderation | channel_name, banned_nickname, reason |
| `ban_exceptions` | Channel Central | channel_name, mask |
| `invite_exceptions` | Channel Central | channel_name, mask |
| `notify_list_entries` | Buddy List | user_nickname, target_nickname, notes |
| `contacts` | Address Book | user_nickname, contact_nickname, notes, group |
| `nick_color_overrides` | Nick Colors | user_nickname, target_nickname, color |
| `highlight_words` | Highlights | user_nickname, word, color |
| `ignore_list_entries` | Ignore System | user_nickname, target_nickname, ignore_type |
| `perform_entries` | Automation | user_nickname, command, position |
| `autojoin_entries` | Automation | user_nickname, channel, key |
| `perform_settings` | Automation | user_nickname, enabled |
| `favorites` | Favorites | user_nickname, target, type, password_encrypted |
| `user_bios` | User Info | nickname, bio_text |
| `aliases` | Scripting | user_nickname, name, command |
| `custom_menu_items` | Scripting | user_nickname, label, command |
| `autorespond_rules` | Scripting | user_nickname, pattern, response |
| `server_settings` | Special Messages | key, value (MOTD, etc.) |
| `channel_welcome_messages` | Special Messages | channel_name, message |
| `notice_routing_settings` | Notices | user_nickname, routing config |
| `ctcp_settings` | CTCP | user_nickname, response config |
| `flood_protection_settings` | Protection | user_nickname, thresholds |
| `sound_settings` | Sounds | user_nickname, event sounds (JSONB) |
| `user_preferences` | Options | user_nickname, 6 JSONB columns (display, chat, etc.) |

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

## Production Deployment

RetroHexChat ships with a multi-stage `Dockerfile` and a `docker-compose.prod.yml` for production deployments. The embedded TURN server requires specific UDP port mappings for WebRTC P2P connections.

### Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| `4000` | TCP | Phoenix HTTP/WebSocket (proxied via HTTPS) |
| `3478` | UDP | TURN server (STUN/TURN signaling) |
| `49152-49651` | UDP | TURN relay ports (~250 concurrent P2P calls) |

### Environment Variables (Production)

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | Yes | PostgreSQL connection string (`ecto://user:pass@host:port/db`) |
| `SECRET_KEY_BASE` | Yes | Phoenix secret (min 64 bytes, generate with `mix phx.gen.secret`) |
| `PHX_HOST` | Yes | Public hostname (e.g. `retrohexchat.app`) |
| `PORT` | No | HTTP port (default: `4000`) |
| `TURN_RELAY_PORT_MIN` | No | TURN relay range start (default: `49152`) |
| `TURN_RELAY_PORT_MAX` | No | TURN relay range end (default: `49651`) |
| `FILE_TRANSFER_MAX_SIZE_MB` | No | Max file transfer size (default: `500`) |

### Health Check

`GET /api/healthz` returns `{"status":"ok"}` with HTTP 200 when the app is running.

### Deploy with Docker Compose

```bash
docker compose -f docker-compose.prod.yml up -d
```

### Deploy with Coolify

1. Create a new application pointing to the repository
2. Set **Build Pack** to `Dockerfile`
3. Set **Port** to `4000`
4. Configure the domain (e.g. `https://retrohexchat.app`)
5. Add **Port Mappings**: `3478:3478/udp` and `49152-49651:49152-49651/udp`
6. Set the environment variables listed above
7. Enable **Force HTTPS** in proxy settings

> **Note:** The `coolify.json` configuration file is not yet supported in Coolify v4 (the feature exists in source but is not active). All configuration must be done via the Coolify UI.

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
| Domain (`retro_hex_chat`) | 70% |
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

This project is governed by a [Constitution](.specify/memory/constitution.md) — 11 non-negotiable principles ratified at project inception:

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
| XI | **User-Facing Documentation** | Every feature must include help topics and keyboard shortcut updates |

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
