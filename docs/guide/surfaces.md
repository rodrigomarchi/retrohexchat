# Surfaces: one module, two hosts

Read when adding a screen that can live in a browser tab of its own, changing
how one is reached, or debugging why a surface behaves differently inside the
chat than at its own address.

Part of the [Agent Guide](../AGENT-GUIDE.md) (§19). Section numbers there are
stable — `§19` still means this file.

---

## 19.1 What a surface is

Everything used to fit in one tab: `/chat` mounted one LiveView, a Win98 desktop
and N windows. Four things now also have an address of their own — a conference,
a space, a P2P session and a match — and the chat still renders every one of
them inside a window. **They are not two implementations.** They are one module
with two mount points:

| Surface | Own address | Module |
|---|---|---|
| conference | `/call/:token` | `App.CallLive` |
| space | `/space/:slug` | `App.SpaceLive` |
| P2P session | `/p2p/:token` | `App.P2PLive` |
| match | `/play/:game/:token` | `App.P2PLive`, opened at its game |
| solo games | `/play`, `/play/:game` | `App.PlayLive` |
| arcade | `/play/arcade/:game` | a redirect, not a LiveView |

Root mount goes through the router; the nested mount is `live_render/3` in a
`desktop_window` slot of the chat. A nested `live_render` runs in its own
process on the same socket, so the embedded mode gets no event loop and no
bundle of its own — which is exactly the trade the embedded mode is accepting.

**A nested `live_render` never passes through the `live_session`'s `on_mount`.**
The chat's window is therefore not a surface: it is part of the chat and dies
with it. Only the route is.

### The ruler that decides what stays in the chat

Applied four times and it has not needed an exception:

> If the datum exists for somebody who is only **looking at the conversation**,
> it lives in the chat. If it exists only while you are **inside**, it belongs
> to the surface.

The tab-bar entry, the sidebar badge, the taskbar button and the status zone are
all on the chat's side of that line, and none of them needs media, devices,
stats or a signalling token. That is what `ChatLive.GroupCallReadModel`,
`ChatLive.SpaceReadModel` and `ChatLive.P2PReadModel` are.

### Testing both mounts

Both, always, and they are different tests. The embedded one drives the chat and
reaches the child through `live_children`; the root one drives the address and
is where the door is asserted. Two things that cost time when forgotten:

- **Drain the mailbox twice** when a control the chat forwards produces a
  `send_update` in the child: the first pass makes the child process the
  forwarded control, and the update is only in the box after that.
- **Ids are unique per document, not per LiveView.** With the surface embedded,
  both hosts render the same components at the same time. Derive internal
  `data-testid`s from the `id` rather than writing them literally.

---

## 19.2 The three things `Live.Surface` does, and the four it must not

`RetroHexChatWeb.Live.Surface` is the `on_mount` every non-chat address carries.
It resolves the nickname from the same Plug session the chat reads, applies the
two refusals that go with it (no session → `/connect`, banned → `/connect` with
the reason), subscribes to `Topics.surfaces/1` for the end of the session, and
registers the process with `RetroHexChat.Surfaces`.

It must **not**:

- announce a takeover — `ChatLive.mount/3` does that on the inbox, and a surface
  doing it would end the chat that opened it;
- track or untrack global presence — that is the chat session's, and a surface
  untracking would make closing a game tab look like going offline;
- write reconnect state, whowas, or a device session — those record what a chat
  session did.

Where a surface *is* comes a moment later, from a `handle_params` hook: the
module says what kind of screen it is, the path says which one.

## 19.3 What differs between the two hosts

`RetroHexChatWeb.Live.SurfaceHost` carries all of it, and the list is short:
a notice, the window, the geometry, and what the host draws about the surface.
Each message carries the surface's **tag**, because the chat hosts more than one
at a time and reading the name beats guessing from the shape.

The channel between the two is the **parent process**, not PubSub: a nested
`live_render` has exactly one host and dies with it, and a topic would deliver
to every tab.

---

## 19.4 Which tabs a person has open

`RetroHexChat.Surfaces` monitors — never asks — every surface process, and it
answers two questions:

1. **May the channels be left yet?** They are left when the *last* surface
   closes. The chat still does it itself when it is the last one; when it is
   not, it hands the departure over with `defer_part/3` and this process runs it
   when the surface that outlived it goes down. Monitors and not `terminate/2`,
   because a crash has to count out exactly like a close.
2. **What is open, and where?** A path per surface, published on
   `Topics.surfaces_open/1` when the set changes. `Live.OpenSurfaces` is how a
   screen reads it.

Two consequences worth not rediscovering:

- **A chat that crashes hands nothing over**, so a membership can outlive both.
  That is what a chat crash already did with no call at all, and closing it
  would mean owning the channel list here continuously for a case that ends in a
  reload.
- The registry keys people by their **downcased** nickname. Build the topic with
  `Surfaces.topic/1`, never by hand: a subscriber using the cased form listens
  to a topic nobody publishes to, silently, and only for people whose nickname
  has a capital in it.

### Cross-tab: the server is the truth, the browser only focuses

Whether a tab exists is the server's answer — it survives `noopener`, survives
two machines, and is the same fact the membership rule already depends on. The
browser adds one thing the server cannot do: bring an existing tab forward.

**Focusing is the bonus; degrading is the requirement.** `window.focus()` from a
background tab is refused often and silently, so a focus request over the shared
`BroadcastChannel` is a question with a 300 ms deadline: the tab holding the
address answers *after* trying, and a request nobody answers resolves as `false`
rather than hanging. The screen then says the tab is open somewhere and lets the
next click follow the link — which is right regardless, because the tab may be
on another monitor or another machine.

`Components.UI.SurfaceTabLink` draws both shapes and is the only thing that
should: a hand-written anchor gets the destructive one wrong, because opening a
second tab of a P2P session **moves the session into it**.

Two things this deliberately does not cover:

- **The taskbar and the Start menu open the chat's own windows, not tabs.**
  There is no second tab to avoid there, so those entries are unchanged. Only
  the four affordances that really open a tab — the three "open in a tab" links
  and every surface's `← Chat` — have two shapes.
- **The arcade tab is reachable by neither half.** `/play/arcade/:game` redirects
  to the static host the WASM bundle lives on, so there is no LiveView for the
  registry to monitor and no shared origin for `BroadcastChannel`. That tab
  cannot be counted or focused, and an arcade session therefore ends by **End
  Session** or by the `SoloSessionServer` inactivity timeout — never because a
  window vanished.

---

## 19.5 Links name a room; they never grant access to one

`RetroHexChat.ShareLinks` mints an opaque slug per surface. `/join/:slug` is the
only public route, runs on the landing pipeline, and resolves the slug to *which
room this is* — never to authorization. Whoever follows it then meets the
surface's own policy. That is what lets the card be public: it carries no secret.

The kinds are `call`, `space`, `p2p` and `play`. A `play` link whose target
carries a `session_token` is a **match**, and it is the only kind that dies by
**success**: a 1v1 game is full the moment somebody takes the seat, so the card
says "already full" rather than "expired".

`ShareLinkRef` is the one place that builds a share URL *and* recognises one.
Two spellings of the same shape is how a link the app produced stops being a
link the app recognises — and the recognition is deliberately narrow: a path
with no host is ours, an absolute URL only when the host matches exactly.

### The door, in this order

Three questions, and the order is not cosmetic:

1. **Does it exist?** (`fetch_session` / `get_room`)
2. **Who are you?** `require_registered` **then** `require_identified`.
3. **What does the domain's policy say?**

Registration and identification are not the same question. Being a participant
is recorded as a `registered_nicks` id, so a nickname that is merely *held*
would otherwise walk into the session of the person who owns it. And the order
matters the other way too: a nickname that is not registered can never be
identified, so inverting them makes one refusal unreachable.

A refusal says the **policy's own sentence**. A generic "not allowed" withholds
the one thing the reader can act on.

---

## 19.6 The product rules the code does not explain

Six decisions taken deliberately. Each of them looks arbitrary in the code and
is not, so changing one means arguing with the reason rather than the line.

- **Every surface has an antechamber, in one of two forms.** You do not fall
  into the thing; you arrive at a door. Which form depends on whether the thing
  is a **place** or an **event**:

  | | Arrival room | Starting room |
  |---|---|---|
  | for | channel call, space | multiplayer match, P2P session |
  | why | it is already happening; you go in when you like | it begins together, somebody decides when |
  | host | no | yes — whoever created it |
  | `[Start]` | no; each person has `[Join]` | yes |
  | persisted | **nothing** — it is render state | `RetroHexChat.Lobby` |

  A `[Start]` on a channel call would be a regression wearing a feature's
  clothes: a call has no owner today, any member opens it and any member walks
  in. And an arrival room stays render state because its roster already exists
  in `GroupCall.get_summary/1` and `VirtualSpace.roster/1` — a table to draw a
  list the runtime already knows would be a second source of truth.

- **No antechamber and no surface has a chat.** `[← Chat]` is always on screen
  and that is the whole answer. A waiting-room chat is a second conversation
  implementation, which is exactly why the standalone `/lobby` was deleted.

- **The character picker *is* the space's antechamber, and choosing is
  entering.** A confirm step after it would be ceremony for walking into a place
  that is already open.

- **The link is born from a button, never from opening the feature.** Opening
  creates the room; **Share** creates the address. If every game window minted a
  `share_link`, the table would be landfill in a week.

- **After it starts, the link still works.** A link spends most of its life
  after minute zero. Call and space let a late click in; a full match says
  "already full" — the one kind that dies by success. A link must never become
  a silent dead end.

- **The host is whoever created it, and a starting room does not outlive them.**
  No host migration: it is a room that lasts minutes, and the right recovery is
  to make another. `[Cancel]` is that rule with a button, and it is gone the
  moment the match starts.

## 19.7 Traps that cost a day each

- **`live_render` wraps the child in a `div` with no height.** An `h-full`
  inside resolves against *that*, not against the window body. Pass
  `container: {:div, class: "h-full min-h-0"}`. No test sees this; only a
  screenshot.
- **Markup that changes owner keeps speaking the old name.** A button moved into
  a surface kept pushing a chat event: nothing fails to compile, nothing fails
  in ExUnit, and the click simply does nothing. When moving markup between
  processes, list the events it emits and check who handles them now.
- **`@socket` inside a template carries no assigns.** A helper that reads them
  there answers its fallback clause forever, silently, and only where it is
  actually used. Pass the value, not the socket.
- **`rel="noopener"` is architecture, not style.** Without it the new tab shares
  the opener's event loop and the separate address buys nothing — measured at
  1203 ms against 12 ms. The cost is that `window.opener` is gone, which is why
  cross-tab coordination is a `BroadcastChannel`.
- **A `refute` in front of a wait-for-it helper is not the negative assertion.**
  It passes the instant the thing is still there. Write the helper that waits
  for it to *go*.
- **A test that exercises only the path its own code builds tests nothing.**
  `/join/:slug` was registered once, outside the locale loop, and sixteen green
  tests missed the `NoRouteError` on `/pt-BR/join/…` because every one of them
  built the path the way the code did. Iterate `SEO.localized_locale_segments/0`
  instead of listing prefixes by hand.
- **Nothing here notices that a screen is ugly.** Every one of the ten defects
  worth remembering from this work — a window laid out at zero height, a
  duplicated card, a camera preview stretched over 440 px of black, a footer
  floating in an almost-empty maximised window, a title bar claiming "Ready"
  about a connection that did not exist — was found by looking at a screenshot,
  and none of them by a test. A new screen gets one before it is called done.
