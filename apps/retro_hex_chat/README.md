# RetroHexChat (Domain)

Pure Elixir domain layer with zero Phoenix dependencies.

Contains 11 bounded contexts:

- **Accounts** — Nickname validation, sessions, authorization
- **Admin** — Admin console, roles, audit logs, server bans
- **Bots** — Bot management and configuration
- **Channels** — GenServer per channel, modes, membership, policy
- **Chat** — Message persistence, history, full-text search
- **Commands** — Parser, dispatcher, and 65 slash-command handlers
- **Config** — Server-level configuration
- **P2P** — Peer-to-peer sessions, file transfer, audio/video calls
- **Presence** — Phoenix.Presence-based user tracking
- **RateLimit** — ETS-backed flood control
- **Services** — NickServ and ChanServ bots with persistent registration

See the [project README](../../README.md) for full documentation.
