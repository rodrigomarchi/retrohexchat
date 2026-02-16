<!--
  Sync Impact Report
  ==================
  Version change: 1.2.0 → 1.3.0 (MINOR: new P2P bounded context + expanded principles)

  Modified principles:
    - Principle II: Added 8th bounded context (RetroHexChat.P2P)
    - Principle III: Added P2P session GenServer to OTP process architecture
    - Principle VII: Added "p2p:#{token}" PubSub topic

  Added sections:
    - Technology Stack: P2P Transport row (WebRTC browser-native API)

  Removed sections: None

  Templates requiring updates:
    - .specify/templates/plan-template.md: ✅ No update needed
      (Constitution Check is dynamically filled from this file by /speckit.plan)
    - .specify/templates/spec-template.md: ✅ No update needed
    - .specify/templates/tasks-template.md: ✅ No update needed
    - .specify/templates/checklist-template.md: ✅ No update needed

  Runtime guidance updates:
    - CLAUDE.md: ⚠️ Update needed when P2P implementation begins
    - MEMORY.md: ⚠️ Update needed when P2P implementation begins

  Follow-up TODOs:
    - Update CLAUDE.md Active Technologies when P2P plans are implemented
    - Update MEMORY.md bounded contexts count (7 → 8)
-->

# RetroHexChat Constitution

## Core Principles

### I. Elixir & Phoenix Exclusive Stack

RetroHexChat MUST be built exclusively in Elixir with the Phoenix Framework.
No alternative backend language or framework will be considered. Phoenix
LiveView MUST be used for all reactive UI — zero JavaScript UI frameworks
(no React, Vue, Svelte, or similar). PostgreSQL MUST be the sole relational
database. 98.css MUST serve as the base design system for the Windows 98
aesthetic.

**Rationale**: A single, cohesive stack eliminates integration friction and
ensures the team speaks one idiom. Elixir/OTP provides the concurrency
model that a real-time chat demands. LiveView removes the JS/backend
synchronization tax.

### II. Umbrella App with Bounded Contexts

The project MUST be structured as a Phoenix umbrella application with strict
separation of responsibilities:

- `retro_hex_chat` — Pure domain logic, business rules. Zero dependency on
  Phoenix or web concerns.
- `retro_hex_chat_web` — Web layer: LiveViews, components, routes, assets.

Within `retro_hex_chat`, the following bounded contexts MUST exist:

- `RetroHexChat.Accounts` — Nick registration, authentication, sessions.
- `RetroHexChat.Chat` — Messages, history, persistence, search.
- `RetroHexChat.Channels` — Channel creation/management, topics, modes,
  membership.
- `RetroHexChat.Services` — NickServ, ChanServ as sub-modules.
- `RetroHexChat.Presence` — Online/away user tracking.
- `RetroHexChat.Commands` — Parser and dispatcher for "/" commands,
  validation, permissions.
- `RetroHexChat.RateLimit` — Flood control.
- `RetroHexChat.P2P` — Peer-to-peer sessions, file transfer, audio/video
  calls via WebRTC.

Each context MUST maintain internal layering: Schema, Queries,
Service/UseCase, Policy, Events.

**Rationale**: Umbrella apps enforce compile-time boundaries. Bounded
contexts prevent domain concepts from bleeding across modules and make
each area independently testable and evolvable.

### III. OTP Process Architecture

A well-defined supervision tree MUST exist from day zero:

- One GenServer per active channel holding state (topic, modes, bans,
  access list).
- A DynamicSupervisor MUST manage channel process lifecycle
  (spawn/terminate).
- A dynamic Registry MUST track active channels via `via_tuple`.
- Dedicated GenServers MUST back NickServ and ChanServ services.
- One GenServer per active P2P session holding state (peers, status,
  lobby messages).

**Rationale**: OTP supervision is the core advantage of the BEAM. Explicit
process architecture ensures fault isolation per channel and graceful
recovery. This is not premature design — it is the foundation of a
reliable chat system.

### IV. Test-First Development (NON-NEGOTIABLE)

TDD MUST be practiced for both Elixir and JavaScript: tests are written
before or alongside implementation, never after. The testing pyramid
MUST be enforced:

- **Unit tests**: Many, fast, no database. `@tag :unit`.
- **Integration tests**: Focused, database-backed. `@tag :integration`.
- **LiveView tests**: Minimal, UI-critical paths. `@tag :liveview`.
- **JS lib tests**: Pure logic functions extracted to `assets/js/lib/`.
- **JS hook tests**: Behavioral tests for LiveView hooks in
  `assets/test/hooks/`.

Required tools and practices:

- ExUnit with `async: true` wherever possible.
- Mox for mocks — based on behaviours only. Direct module mocking is
  forbidden.
- ExMachina for data factories.
- StreamData for property-based testing of parsers and validations.
- Floki for HTML parsing in LiveView tests.
- Vitest with jsdom for JavaScript tests.
- `mix test` MUST complete in under 60 seconds.
- `mix test --only unit` MUST complete in under 10 seconds.
- Test coverage MUST NOT regress — every new feature MUST maintain or
  increase coverage.

JavaScript hooks MUST follow the "hook = wiring, lib = logic" pattern:
all testable logic MUST be extracted to `assets/js/lib/` modules with
semantic function names, and hooks MUST only wire DOM events to lib
functions and LiveView pushEvent calls.

**Rationale**: TDD catches defects at the cheapest point. The pyramid
ensures fast feedback loops while still covering integration boundaries.
Strict time budgets prevent test suites from becoming a bottleneck.
Applying TDD to JavaScript ensures hooks remain reliable as the UI
evolves.

### V. Contracts and Behaviours

Behaviours (`@callback`) MUST define contracts between modules. Each "/"
command MUST be a separate module implementing a `Handler` behaviour.
Protocols MUST be used where polymorphic dispatch adds clarity (e.g.,
message formatting).

**Rationale**: Explicit contracts make module boundaries machine-verifiable
via Dialyzer and enable Mox-based testing. One-module-per-command keeps
the command system open for extension without modifying existing code.

### VI. Static Analysis from Day One

The following tools MUST be configured and enforced from the first commit:

- **Credo** for Elixir lint — all warnings MUST be resolved.
- **Dialyxir** for type checking — `@spec` annotations MUST exist on all
  public functions.
- **`mix format --check-formatted`** MUST pass — no unformatted Elixir code.
- **ESLint** for JavaScript lint — all errors MUST be resolved.
- **Prettier** for JavaScript formatting — all files MUST be formatted.

**Rationale**: Static analysis catches entire classes of defects that tests
miss. Enforcing it from day one prevents accumulated technical debt that
becomes painful to retrofit. Applying the same rigor to JavaScript ensures
hooks and lib modules stay clean and consistent.

### VII. Lean LiveViews & Component Architecture

LiveView modules MUST be thin — they delegate all logic to contexts. Zero
business logic in the web layer. Reusable LiveView function components
MUST encapsulate each visual element. JavaScript hooks MUST be minimal
and isolated (scroll behavior, sounds, keyboard shortcuts only).

PubSub topics MUST follow a clear naming convention:

- `"channel:#{name}"` for channel events.
- `"user:#{nickname}"` for user-scoped events.
- `"service:nickserv"`, `"service:chanserv"` for service events.
- `"p2p:#{token}"` for P2P session events.

LiveView streams MUST be used for long message lists to ensure performance.

**Rationale**: Thin LiveViews are testable, composable, and keep the web
layer a pure presentation concern. Consistent PubSub topics prevent
subscription bugs. Streams prevent memory bloat on high-traffic channels.

### VIII. Windows 98 Design Fidelity

The UI MUST faithfully reproduce the Windows 98 aesthetic:

- 98.css as the base design system, with a dark theme as the default.
- 3D beveled borders, pixelated fonts, 16x16 icons.
- Monospace fonts in chat areas (Fixedsys / Consolas / Courier New).
- Semantic HTML as required by 98.css for accessibility.
- Telemetry events MUST be emitted at critical interaction points.

**Rationale**: The retro aesthetic is the product's identity. Cutting
corners on visual fidelity undermines the core value proposition.
Semantic HTML ensures the nostalgic UI remains accessible.

### IX. Hot/Cold Data Separation

Runtime state (active channels, online users, rate-limit counters) MUST
live in GenServers and/or ETS — hot data stays in-memory. Persistent
data (message history, user accounts, channel configs) MUST live in
PostgreSQL — cold data stays on disk.

Migrations MUST be organized and incremental. Soft deletes MUST be used
where business context requires auditability. Configuration MUST be
environment-aware (dev, test, prod) from the first commit.

**Rationale**: Separating hot and cold data is the BEAM's natural model.
In-memory state delivers sub-millisecond reads for real-time features;
PostgreSQL provides durability and queryability for everything else.

### X. Scalable Architecture

Every architectural decision MUST be evaluated for future scalability.
The system MUST support growth without requiring a rewrite. Specifically:

- Process-per-channel MUST scale horizontally via distributed Erlang or
  a future clustering strategy.
- Database schemas MUST be designed for partitioning if needed.
- PubSub MUST be backed by a mechanism that can span nodes (Phoenix
  PubSub with pg adapter or similar).

Premature optimization is forbidden, but premature architectural
dead-ends are equally forbidden. Simplicity MUST be the default — but
never at the cost of painting the system into a corner.

**Rationale**: A chat system's load grows non-linearly. Decisions made
early (process architecture, data model, PubSub topology) are expensive
to reverse. This principle ensures we choose the simple path that remains
extensible.

### XI. User-Facing Documentation (Mandatory)

Every user-facing feature MUST include corresponding help documentation
in the integrated help system (`RetroHexChat.Chat.HelpTopics`). This is
not optional — undocumented features are considered incomplete.

Requirements:

- Every new slash command MUST have a help topic with syntax, examples,
  and "See Also" cross-references.
- Every new UI feature (window, dialog, toolbar, shortcut) MUST have a
  help topic explaining its purpose and usage.
- Every new service command (NickServ, ChanServ) MUST have a help topic.
- Help topics MUST be accessible via the CHM-style Help dialog (F1) and
  the `/help` command.
- The Help menu in the menu bar MUST provide access to the help system.
- Help content MUST be kept in sync with feature behavior — stale or
  inaccurate documentation is a defect.

**Rationale**: A feature that users cannot discover or learn to use
delivers zero value. The Windows 98 CHM-style help system is a core part
of the retro aesthetic and must grow alongside the application. Treating
documentation as a first-class deliverable ensures the help system
remains comprehensive and trustworthy.

## Technology Stack & Constraints

| Layer | Technology | Version/Notes |
|-------|-----------|---------------|
| Language | Elixir | Latest stable |
| Framework | Phoenix | Latest stable |
| Reactive UI | Phoenix LiveView | No JS UI frameworks |
| Database | PostgreSQL | Primary persistent store |
| Design System | 98.css | Dark theme default |
| Process Management | OTP (GenServer, DynamicSupervisor, Registry) | Core architecture |
| Testing (Elixir) | ExUnit, Mox, ExMachina, StreamData, Floki | Full pyramid |
| Testing (JS) | Vitest, jsdom | Hook + lib tests |
| Static Analysis (Elixir) | Credo, Dialyxir, mix format | Enforced from day one |
| Static Analysis (JS) | ESLint, Prettier | Enforced from day one |
| P2P Transport | WebRTC (browser-native API) | No JS frameworks |
| CSS Fonts | Fixedsys / Consolas / Courier New | Monospace in chat |

**Forbidden technologies**: React, Vue, Svelte, Angular, or any
JavaScript UI framework. No alternative backend languages. No NoSQL as
primary store.

## Development Workflow & Quality Gates

### Pre-Commit Gates

Every change MUST pass before merge:

1. `mix format --check-formatted` — No unformatted Elixir code.
2. `mix credo --strict` — No Elixir lint violations.
3. `mix dialyzer` — No typespec violations.
4. `mix test` — All Elixir tests green, under 60 seconds.
5. `npx eslint js/ test/` — No JavaScript lint violations.
6. `npx prettier --check js/ test/` — No unformatted JavaScript code.
7. `npx vitest run` — All JavaScript tests green.

### Code Organization Gates

- LiveViews MUST NOT contain business logic.
- Context modules MUST NOT depend on Phoenix or web concerns.
- Every public function MUST have a `@spec`.
- Every "/" command MUST implement the `Handler` behaviour.
- PubSub topics MUST follow the documented naming convention.

### Feature Delivery Workflow

1. Spec defines the feature (specification as source of truth).
2. Tests are written first (red phase).
3. Implementation makes tests pass (green phase).
4. Refactor while tests stay green.
5. Static analysis gates pass.
6. Help topics added/updated for all user-facing changes (Principle XI).
7. Review and merge.

## Governance

This constitution is the supreme governing document of the RetroHexChat
project. All code, architecture decisions, and development practices
MUST comply with the principles defined herein.

### Amendment Procedure

1. Proposed amendments MUST be documented with rationale.
2. Amendments MUST include a migration plan for existing code if the
   change affects current implementations.
3. Version MUST be incremented per semantic versioning:
   - **MAJOR**: Principle removed or fundamentally redefined.
   - **MINOR**: New principle added or existing principle materially
     expanded.
   - **PATCH**: Wording clarifications, typo fixes, non-semantic
     refinements.

### Compliance Review

- Every pull request MUST be verified against this constitution.
- The plan template's "Constitution Check" section MUST enumerate which
  principles are relevant to the feature and confirm compliance.
- Violations MUST be justified in the plan's "Complexity Tracking" table
  or rejected.

### Runtime Guidance

For day-to-day development guidance that supplements this constitution,
refer to `CLAUDE.md` and project-level documentation. This constitution
defines *what* is non-negotiable; runtime guidance addresses *how*.

**Version**: 1.3.0 | **Ratified**: 2026-02-09 | **Last Amended**: 2026-02-16
