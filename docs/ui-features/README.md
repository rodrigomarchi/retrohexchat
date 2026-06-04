# UI Feature Specs — implementation backlog

One spec document per feature that needs UI work. These are **design specifications**
(descriptions, layouts, control→command mappings), **not** code. Each is grounded in the
real command handler source — every command fact is quoted from the handler, with
source-vs-assumption caveats flagged.

Derived from the coverage analysis in [`../ui-feature-coverage.md`](../ui-feature-coverage.md)
(§5 Feature groups). Only the 12 features that are **not** already ✅ complete have a spec
here; the 5 complete features (Ignore, P2P & Media, Connect Automation, Connection/Session,
Help) need no work.

**Operational files:**
- [`PROGRESS.md`](PROGRESS.md) — shared progress + learnings log (status board, updated every iteration).
- [`IMPLEMENTATION_PROMPT.md`](IMPLEMENTATION_PROMPT.md) — the loop prompt for AI agents; cites the project's governing docs on how to build increments here.

Verdict legend: ❌ command-only (no launcher) · ⚠️ dark dialog (built, not wired) · 🟡 partial.

| # | Spec | Verdict today | Priority | One-line gap |
|---|------|---------------|----------|--------------|
| 01 | [Identity, Account & Presence](01-identity-account-presence.md) | ❌ | **P0** | `/ns` register/identify, `/away`, `/bio`, `/nick`, `/umode` — entire login journey has no launcher |
| 02 | [Buddy List (Notify)](02-buddy-list-notify.md) | ⚠️ | **P0** | Notify List dialog exists but is reachable only via `/notify` — wire into View menu |
| 03 | [Bots](03-bots.md) | ⚠️ | **P0** | Bot Management dialog exists but is reachable only via `/bot` — wire into Tools menu |
| 04 | [Window & Display (Edit menu)](04-window-display-edit-menu.md) | ❌ | **P1** | No Edit menu; `/clear` has no menu item; Find lives under View |
| 05 | [Channel Moderation](05-channel-moderation.md) | 🟡 | **P1** | Context menus are grant-only — no Remove Op/Voice, no channel Mute/Unmute |
| 06 | [Channel Membership](06-channel-membership.md) | 🟡 | **P1** | Sending an invite has no UI (Invite dialog is receive-only); `/knock` has none |
| 07 | [Messaging](07-messaging.md) | 🟡 | P2 | `/me` (action) and `/notice` have no UI control |
| 08 | [Scripting & Customization](08-scripting-customization.md) | 🟡 | P2 | `/timer` (scheduled commands) has no dialog |
| 09 | [Channel Configuration](09-channel-configuration.md) | 🟡 | P2 | `/slow`, `/transfer`, `/setwelcome` missing from Channel Central |
| 10 | [User Lookups](10-user-lookups.md) | 🟡 | P3 | `/whowas` has no UI; whois output is raw status text |
| 11 | [ChanServ (channel registration)](11-chanserv.md) | ❌ | P3 | `/cs` register/access lists have no UI for normal users |
| 12 | [Server Administration](12-server-administration.md) | 🟡 | P3 | `/motd`, `/wallops`, `/announce`, `/singleplayer` have no dedicated UI |

## Spec template

Every document follows the same structure:

1. **Overview** — what it is, who uses it, why it needs UI
2. **Commands (grounded in handler source)** — real syntax, behavior, permissions
3. **Current UI state** — what exists vs what's missing
4. **UI specification** — entry points · layout (with ASCII wireframes) · interactions & states · control→command mapping
5. **Permissions & visibility** — gating rules
6. **Help documentation** — HelpTopics to add/update (mandatory per project premise)
7. **Out of scope / open questions**

## Cross-cutting conventions (apply to all specs)

- **Enhance existing components, never create parallel ones** — e.g. ChanServ (11) and
  Channel Configuration (09) extend the existing **Channel Central** dialog rather than
  adding new dialogs.
- **Help docs are mandatory** — each implemented feature must add/update `Chat.HelpTopics`
  and cross-references before it's considered done.
- **No inline SVGs / no hardcoded colors** — follow the SVG and CSS rules in the root
  `CLAUDE.md` when implementing.
- **Wiring before building** — the two ⚠️ dark-dialog specs (02, 03) are mostly "add a menu
  entry to an existing dialog" and are the cheapest wins.
