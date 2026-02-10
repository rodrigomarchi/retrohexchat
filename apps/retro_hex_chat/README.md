# RetroHexChat (Domain)

Pure Elixir domain layer with zero Phoenix dependencies.

Contains 7 bounded contexts:

- **Accounts** — Nickname validation, sessions, authorization
- **Chat** — Message persistence, history, full-text search
- **Channels** — GenServer per channel, modes, membership, policy
- **Commands** — Parser, dispatcher, and 18 slash-command handlers
- **Services** — NickServ and ChanServ bots with persistent registration
- **Presence** — Phoenix.Presence-based user tracking
- **RateLimit** — ETS-backed flood control

See the [project README](../../README.md) for full documentation.
