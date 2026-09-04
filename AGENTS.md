# AGENTS.md — retro_hex_chat

A Windows-98 / mIRC-flavoured chat: Elixir umbrella, Phoenix LiveView, PostgreSQL,
Tailwind, WebRTC. `apps/retro_hex_chat` is the domain and carries **no web layer** —
no LiveView, controller, route, component or endpoint lives there. It does reach
for Phoenix as a library (`Phoenix.PubSub`, `Phoenix.Token`, `Phoenix.Presence`,
HTML escaping), which is why `{:phoenix, ...}` is in its `mix.exs`.
`apps/retro_hex_chat_web` is the only place web concerns live. That boundary is
the one structural rule you cannot infer from a file listing.

Run `make help` for the full target list and `mix help` for Mix tasks. Explore the
tree rather than trusting a directory map — this file deliberately does not carry one.

## Stack

Elixir 1.17+ / OTP 27+, Phoenix 1.8+, Phoenix LiveView 1.0+, Ecto 3.x, PostgreSQL 16+,
Tailwind (`retrohex.css`) + esbuild. Exact versions live in `mix.exs` and `package.json`.

The parts you would not guess:

- **Postgres uses cursor-based pagination with GIN/trigram indexes** — not offset paging.
- **In-memory state is GenServer/ETS at runtime**, `Session` structs for guests, and
  localStorage on the client. Reach for the right tier before adding a table.
- **Oban owns all background work**, and observability is part of "done" (`AGENT-GUIDE` §17).
- **PromEx exports Prometheus metrics at `/metrics`**; the Grafana dashboards are
  provisioned from a separate infra repository, not from here.
- `bcrypt_elixir` for password hashing, `Plug.Crypto` for encryption, `Req` for the
  link-preview HTTP client, `ExSTUN` for WebRTC signaling.

## The completion gate

**`make ci` is the only acceptable final gate.** Staged, partitioned, ~3m warm.
If any check fails, the task is not complete.

`make ci.quick`, `make ci.changed`, stale tests and Playwright smokes are iteration
tools. They never replace the final `make ci` pass.

Two traps worth knowing before you run it:

- **A pipe masks the exit code.** `make ci 2>&1 | tail -20` returns `tail`'s status
  (0). Use `make ci > log 2>&1; echo $?`, or read the `Results:` line it prints.
- **Run `mix format` first.** A long `send_update`/pipe line breaks format and
  cascade-skips later parallel stages, wasting a whole round-trip.

Mechanics, options, partitions, browser E2E and deploy: [`docs/reference/ci-pipeline.md`](docs/reference/ci-pipeline.md).

## Deploy

**Always `make deploy`** — it runs the full CI pipeline, then ships to Sun
(production). **Never `make deploy-sun` directly: it skips CI validation.**
Use `make deploy.skip-ci` only when `make ci` just passed on this exact revision.

**`make e2e.full` before a release.** `make ci` proves the server; it never
opens a browser. The first whole-suite run found real failures behind a green
`make ci` — among them a dialog that drew a channel mode it did not have, and a
window that never handed the keyboard over. Too slow for the commit gate, cheap
once per release. The spec inventory is `e2e/TEST_CATALOG.md`.

## Git

This repository commits straight to `main`, and more than one person pushes in
parallel. Before any commit or push:

```bash
git fetch origin
git status --short --branch
git pull --ff-only origin main      # --autostash if you have uncommitted edits
```

- **Stage exact paths — never `git add -A`.** The working tree may carry unrelated
  uncommitted work.
- **Never `git checkout <file>` to undo edits while work is uncommitted** — it
  reverts to HEAD and destroys *other* uncommitted work too. Undo with an editor,
  or a recoverable `git stash push -- <file>`. Recover a lost stash with
  `git fsck --no-reflog | grep "dangling commit"`.

## Code conventions

- **Every public function MUST have `@spec`.**
- **LiveViews MUST be thin** — delegate to domain contexts. LiveViews contain no
  business logic; contexts contain no LiveViews, controllers or components.
- **Each `/` command is a separate Handler module.**
- **PubSub topics:** `"channel:#{name}"`, `"user:#{nickname}"`, `"game:#{token}"`.
  A private conversation has no topic of its own — it is delivered to each
  participant's `user:` inbox, because a conversation has no join and its first
  message would have nobody listening. Build both names with `RetroHexChat.Topics`.
- **Comments describe what the code does, never the change that produced it.** No
  migration or plan references in moduledocs or comments.
- **Alias on first write.** Alias a new module call in the same edit — never wait
  for Credo to tell you.
- **No silent catch, JS or Elixir.** A catch-all `handle_info` that eats a message
  you depend on is the same bug class as a swallowed `try/catch`.
- **When the spec contradicts the code, trust the code and record the discrepancy.**
  Specs lag reality on key bindings, menu names and permission gates.

## Where the rest lives

Read these when the trigger applies — not before.

| Read | When |
|---|---|
| [`docs/AGENT-GUIDE.md`](docs/AGENT-GUIDE.md) | **Start here for any non-trivial change.** The governing principles, state tiers, command/dispatch spine, PubSub & permissions, persistence, UI composition, CSS/SVG, mIRC parity, help, process discipline, JS bundle standard, i18n & public URLs |
| [`docs/guide/liveview-islands.md`](docs/guide/liveview-islands.md) | Extracting or debugging a LiveComponent island |
| [`docs/guide/windowed-desktop.md`](docs/guide/windowed-desktop.md) | Adding or changing a window, dialog, taskbar or Start menu entry |
| [`docs/guide/webrtc-p2p.md`](docs/guide/webrtc-p2p.md) | Calls, signaling, TURN, file transfer, call recovery |
| [`docs/guide/surfaces.md`](docs/guide/surfaces.md) | A screen with an address of its own: the two mounts, the share link, cross-tab |
| [`docs/guide/testing.md`](docs/guide/testing.md) | Writing or debugging tests |
| [`docs/guide/background-jobs.md`](docs/guide/background-jobs.md) | Oban workers, queues, recurrence, observability |
| [`docs/guide/mobile-touch.md`](docs/guide/mobile-touch.md) | Viewport, touch handling, mobile dialogs |
| [`docs/reference/ci-pipeline.md`](docs/reference/ci-pipeline.md) | A check fails, tuning partitions, browser E2E, deploy |
| [`docs/README.md`](docs/README.md) | The full documentation index |
| [`virtual.space/`](virtual.space/) | Generating or debugging virtual-space pixel art |
| [`e2e/README.md`](e2e/README.md) | The Playwright suite |

## Documentation is part of the change

- **Help topics are mandatory — for anything the reader can act on.** Every change
  that adds a command, control, setting, shortcut or behaviour to anticipate updates
  `RetroHexChat.Chat.HelpTopics`. Something with no control surface — styling, a
  colour, a wallpaper — gets no topic: help answers "how do I…", not "what am I
  looking at". Stale help is a defect; help nobody can act on is noise.
  (`AGENT-GUIDE` §12)
- **Durable, cross-cutting learning** → `docs/AGENT-GUIDE.md` or a `docs/guide/` playbook.
- **Living inventory that must track the code** → `docs/reference/`, linked from
  `docs/README.md`. If the code can answer the question directly — grep a module,
  open `/showcase/icons` — do not write the inventory at all.
- **Runbooks document themselves in place**, beside the thing they operate.
- **Never write counts into prose** (migrations, contexts, icons, hooks). They rot
  silently and mislead; every one of them in this repo was wrong before this file
  was rewritten. Point at the directory instead.
