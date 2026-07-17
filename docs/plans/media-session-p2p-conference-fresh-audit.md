# Fresh Audit and Product Plan: P2P and Conference Media Sessions

Date: 2026-07-16

This audit is based on fresh Playwright captures and current code inspection only. Older planning documents were not used as evidence for the findings below.

## Evidence Captured

Screenshots were captured under `docs/plans/screenshots/media-session-audit/`.

P2P:

- [desktop setup](screenshots/media-session-audit/p2p-desktop-setup.png)
- [desktop invite card](screenshots/media-session-audit/p2p-desktop-invite-card.png)
- [desktop call](screenshots/media-session-audit/p2p-desktop-call.png)
- [desktop call with stats](screenshots/media-session-audit/p2p-desktop-call-stats.png)
- [mobile setup](screenshots/media-session-audit/p2p-mobile-setup.png)
- [mobile invite card](screenshots/media-session-audit/p2p-mobile-invite-card.png)
- [mobile post-connect](screenshots/media-session-audit/p2p-mobile-post-connect.png)

Conference:

- [desktop prejoin](screenshots/media-session-audit/conference-desktop-prejoin.png)
- [desktop single user](screenshots/media-session-audit/conference-desktop-single.png)
- [desktop two users](screenshots/media-session-audit/conference-desktop-two-users.png)
- [desktop call with stats](screenshots/media-session-audit/conference-desktop-call-stats.png)
- [mobile prejoin](screenshots/media-session-audit/conference-mobile-prejoin.png)
- [mobile single user](screenshots/media-session-audit/conference-mobile-single.png)
- [mobile stats](screenshots/media-session-audit/conference-mobile-stats-attempt.png)

Validation run:

- Temporary Playwright audit spec passed: 2 tests, Chromium.
- The temporary spec was used only to capture the current UI state and should not become a permanent test as-is.

Implementation screenshots from the first product pass were captured under `docs/plans/screenshots/media-session-implementation/`.

P2P implementation:

- [desktop setup](screenshots/media-session-implementation/p2p-desktop-setup.png)
- [desktop call](screenshots/media-session-implementation/p2p-desktop-call.png)
- [desktop files](screenshots/media-session-implementation/p2p-desktop-files.png)
- [desktop games](screenshots/media-session-implementation/p2p-desktop-games.png)
- [desktop stats](screenshots/media-session-implementation/p2p-desktop-stats.png)
- [mobile setup](screenshots/media-session-implementation/p2p-mobile-setup.png)
- [mobile call](screenshots/media-session-implementation/p2p-mobile-call.png)
- [mobile stats](screenshots/media-session-implementation/p2p-mobile-stats.png)

Conference implementation:

- [desktop prejoin](screenshots/media-session-implementation/conference-desktop-prejoin.png)
- [desktop call](screenshots/media-session-implementation/conference-desktop-call.png)
- [desktop settings](screenshots/media-session-implementation/conference-desktop-settings.png)
- [desktop stats](screenshots/media-session-implementation/conference-desktop-stats.png)
- [mobile prejoin](screenshots/media-session-implementation/conference-mobile-prejoin.png)
- [mobile call](screenshots/media-session-implementation/conference-mobile-call.png)
- [mobile people](screenshots/media-session-implementation/conference-mobile-people.png)
- [mobile settings](screenshots/media-session-implementation/conference-mobile-settings.png)
- [mobile stats](screenshots/media-session-implementation/conference-mobile-stats.png)

Post-legacy visual QA screenshots were captured under `docs/plans/screenshots/media-session-post-legacy-qa/`.

P2P post-legacy QA:

- [desktop call](screenshots/media-session-post-legacy-qa/p2p-desktop-call.png)
- [desktop files](screenshots/media-session-post-legacy-qa/p2p-desktop-files.png)
- [desktop games](screenshots/media-session-post-legacy-qa/p2p-desktop-games.png)
- [desktop stats](screenshots/media-session-post-legacy-qa/p2p-desktop-stats.png)
- [mobile call](screenshots/media-session-post-legacy-qa/p2p-mobile-call.png)
- [mobile files](screenshots/media-session-post-legacy-qa/p2p-mobile-files.png)
- [mobile games](screenshots/media-session-post-legacy-qa/p2p-mobile-games.png)
- [mobile stats](screenshots/media-session-post-legacy-qa/p2p-mobile-stats.png)

Conference post-legacy QA:

- [desktop call](screenshots/media-session-post-legacy-qa/conference-desktop-call.png)
- [desktop people](screenshots/media-session-post-legacy-qa/conference-desktop-people.png)
- [desktop settings](screenshots/media-session-post-legacy-qa/conference-desktop-settings.png)
- [desktop stats](screenshots/media-session-post-legacy-qa/conference-desktop-stats.png)
- [desktop mini](screenshots/media-session-post-legacy-qa/conference-desktop-mini.png)
- [mobile call](screenshots/media-session-post-legacy-qa/conference-mobile-call.png)
- [mobile people](screenshots/media-session-post-legacy-qa/conference-mobile-people.png)
- [mobile settings](screenshots/media-session-post-legacy-qa/conference-mobile-settings.png)
- [mobile stats](screenshots/media-session-post-legacy-qa/conference-mobile-stats.png)
- [mobile mini](screenshots/media-session-post-legacy-qa/conference-mobile-mini.png)

Post-legacy validation:

- Temporary Playwright visual QA spec passed: 2 tests, Chromium.
- The same capture pass asserted that removed legacy surfaces were absent: P2P top-level Files/Games/Stats windows and conference `group-call-stats` dock/window/taskbar IDs.
- Visual inspection found one mobile regression in the shared section navigation: the right scroll cue could cover the active Settings tab. This was fixed in `SectionNav` by moving the cue indicators outside the scrollable tab strip and rebuilding the served CSS asset.

## Executive Summary

P2P and conference should be treated as one media-session UI system with different capabilities, not as two unrelated features. The visual language, control density, stats pattern, prejoin/setup model, and mobile reachability need to converge.

The biggest P2P problem found in the audit was structural: desktop opened a burst of windows, but mobile skipped that burst, so after accepting a session the user remained in chat with only a small status/tab signal. The UI said the session windows would open shortly, but on mobile the code intentionally did not open those windows. This made the connected P2P session hard to use on mobile.

Status after implementation pass 1: this P2P reachability issue is fixed. P2P now opens a unified session console on mobile and desktop.

The biggest conference problem from the initial audit was polish and density: mobile did open the call surface, so the flow was more reachable than P2P, but the surface was visually heavy. Large icons, wide controls, a participant panel, and stats competed for very limited space.

Status after implementation pass 2: conference now has the same explicit session-section language as P2P. Call, People, Stats, and Settings are first-class sections; desktop keeps the richer stage-plus-inspector layout, while mobile uses the same sections as focused modes instead of stacking every panel into the Call view.

Status after implementation pass 3: P2P and conference stats now use a summary-first hierarchy. Health, latency, media, and data/room status appear before raw transport details, while all existing advanced metrics remain available.

## Current Source Of Truth After Fine Audit

Audit date: 2026-07-17.

The sections below this point include the original audit, the implementation blueprint, and historical "remaining work" notes. Treat those older notes as decision history unless the item is restated in this section.

Original plan status:

- P2P default experience is now one reachable `P2PSessionConsole` on mobile and desktop.
- P2P Call, Files, Games, and Stats are console sections; Files/Games remain independently stateful while sharing the same P2P connection.
- P2P receive-only, audio-only, recovery, screen share, file transfer, game invite/waiting/playing/result, and stats flows are covered by focused tests and full P2P E2E.
- Conference now uses the same section vocabulary: Call, People, Stats, Settings.
- Conference People, request-to-speak/moderation, Stats, Settings, mobile Call tile layout, and mini mode were refined with desktop/mobile screenshots.
- P2P and conference both use the shared media-session presentational layer where it currently pays off: `Header`, `CommandBar`, `IconButton`, `ActionButton`, `SectionNav`, `InspectorPanel`, `StatusHeader`, `SummaryCard`, and `DiagnosticsGroup`.
- Shared `SectionNav` now renders mobile scroll cues as reserved side slots instead of overlaying tab labels; the same behavior is used by P2P and conference.
- Old P2P top-level Files/Games/Stats windows are not a product path. Remaining `p2p-stats-*`, `p2p-files-*`, and `p2p-games-*` selectors are feature-level section selectors, not managed-window IDs.
- Conference Stats is only an inline section of `group-call`; the former `group-call-stats` dock/window/taskbar path has been removed.

Resolved historical backlog:

- "P2P mobile reachability" is resolved.
- "P2P opens a burst of separate default windows" is resolved for the shipped default.
- "Conference People/Stats/Settings need explicit section/inspector language" is resolved.
- "Stats should be summary-first, raw details later" is resolved for P2P and conference.
- "P2P Files/Games need to live inside the session workspace while preserving concurrency" is resolved.
- "Conference mobile Call/People/Stats/Settings need a unified mobile-first experience" is resolved at the current visual QA level.
- "Mini mode inherits hidden inspector space" is resolved.
- "Dead P2P managed window IDs and stale P2P stats-window CSS" were cleaned in Pass 24.

Real remaining items:

1. Permanent visual regression policy is still optional/undecided.
   - Current state: focused E2E layout stability checks exist, and temporary Playwright specs captured audited screenshots, then were removed.
   - Remaining decision: if visual screenshots should become part of the normal suite, add a deliberate golden/screenshot workflow for the final P2P and conference states instead of reintroducing ad hoc `.tmp.spec` files.

2. Documentation lifecycle cleanup remains.
   - This file is now a long historical audit log. It is useful while the work is active, but risky as permanent source material because old "current state" sections are intentionally stale.
   - When the user accepts the media-session work as complete, either archive this file or replace it with a short final source-of-truth document.

3. Shared component extraction should stop unless it removes real duplication.
   - Missing originally proposed names such as a full `shell.ex`, `metric_badge.ex`, or `setup_layout.ex` are not product blockers.
   - Add them only if a future pass proves the abstraction reduces complexity without owning media/game/file lifecycle.

4. Legacy window compatibility has been removed from the mapped P2P/conference paths.
   - `P2PFileIsland`, `P2PGameIsland`, and `P2PMediaIsland` no longer own `window_id`/`close_window_on_*` contracts or emit window commands.
   - The conference no longer has a separate `group-call-stats` dock/window/taskbar path; Stats is an inline section of `group-call`.
   - Menu/start/badge Stats/Files/Games shortcuts now route through `p2p_console_select` with a section.

No current blocker was found in the original plan that prevents considering the P2P + conference mobile/desktop elevation functionally delivered at the current quality bar.

## Current State: P2P

### Desktop

P2P setup is functional but too tall and visually dense. The preview, connection explanation, topology block, media toggles, devices, and privacy option all compete inside the dialog. The hierarchy should be: preview and peer intent first, devices second, topology/privacy as lower-emphasis supporting detail.

The invite card inside chat is acceptable. It is compact enough, has visible Accept/Decline actions, and does not need to be the first target of redesign.

The connected call experience is the larger problem. The desktop flow opens P2P Call, P2P Statistics, P2P Files, and P2P Games as separate windows. This is consistent with the retro desktop metaphor, but the default state creates a fragmented workspace. The video/call window dominates the screen, while stats and other tools compete in the taskbar or as overlapping windows.

The call panel itself uses very large icons and controls. In `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/p2p/call_panel.ex`, many icons are `h-8 w-8` and the action button helper uses `h-10 w-10`. That makes the interface feel more like a debug/control board than a refined media surface.

### Mobile

P2P setup fits, but it is desktop content stacked vertically. It is usable, but not optimal: preview, topology explanation, settings, devices, and actions form a long scroll. The primary job is to help the user confidently send or accept a media invite; topology should be compact and secondary.

The mobile invite card is acceptable. It shows the core state and actions in view.

The post-connect mobile state was the critical failure in the initial audit. The user remained in the chat after the peer accepted. A small P2P status strip appeared, and the transcript said calls/files/games were available, but no proper mobile session surface opened. The audited code confirmed this:

- `p2p_session_events.ex` skips auto-start when `mobile_viewport` is true.
- `burst_windows/1` returns the socket unchanged on mobile, so P2P Call, Files, Games, and Stats are not opened.

This meant mobile P2P was connected at the protocol/state layer but not properly delivered at the UX layer. Implementation pass 1 replaced this with the P2P Session Console.

## Current State: Conference

### Desktop

Conference prejoin is better balanced than P2P setup because it has fewer feature branches. It still has the same issue: a large topology explanation and device controls receive nearly the same visual weight as the preview and join action.

The connected conference call has a better default structure than P2P. It opens one primary surface with header, stage, participants, and bottom controls. This is the direction P2P should move toward.

The desktop conference surface still needs refinement. Header icons, status icons, toolbar icons, participant icons, and reaction controls are repeatedly `h-8 w-8`, while buttons commonly use `h-10 w-10`. The result is a heavy chrome layer around a media stage that should feel calmer and more focused.

Implementation pass 2 reduced this chrome weight and added explicit section navigation. Desktop now keeps Call as the primary surface, People and Settings as inspectors, and Stats as the existing docked diagnostics window behind the same section language.

The stats dock is readable on desktop, but it competes with the call surface. It should become an inspector pattern: summary first, details second, and a predictable dock/tab behavior shared with P2P.

### Mobile

Conference mobile is materially ahead of P2P because it opens the call surface after joining. Current code confirms that mobile calls `Windows.open(socket, @window_id)` for the main conference window.

The mobile conference surface is still crowded. The call header, top toolbar, left rail, participant panel, video area, bottom controls, and reaction controls all appear in a very narrow viewport. The user can operate it, but the UI is not yet a high-quality mobile-first experience.

Implementation pass 2 removed the worst mobile competition: Call no longer has to show the participant panel just because the desktop sidebar is enabled. People is now a focused mobile section, Settings is a focused mobile section, and the layout-control rail consumes only its content height instead of reserving a tall empty band.

The mobile stats screen is reachable but too technical. It presents server/runtime/peer metrics as dense rows. For a mobile media feature, stats should start with a concise health summary and let advanced details expand.

## Community Practice Baseline

For media sessions, the common product pattern is:

- A reachable primary session surface immediately after join/accept.
- One stable mental model across mobile and desktop.
- Mobile-first layout that desktop expands with side panels, not a separate interface.
- Persistent core controls: mute, camera, share, people, stats, leave.
- Compact icons inside adequate hit targets: the hit area can be 36-44px, but the icon itself should usually be 14-20px.
- Prejoin/setup focused on preview, device confidence, and the join/send action.
- Diagnostics behind progressive disclosure: health summary first, raw metrics later.
- Secondary surfaces as tabs, sheets, or docked inspectors, not hidden behind window/taskbar discovery on mobile.

## Product Ambition: Complete Product, Not MVP

The goal is not to patch responsiveness, shrink a few icons, or ship a minimal mobile variant. The goal is to turn P2P and conference into a polished media product inside RetroHexChat.

That means the work must solve:

- Flow: users can start, accept, join, operate, inspect, and leave sessions without hunting for hidden surfaces.
- Information architecture: every feature has a predictable home.
- Visual hierarchy: media content is primary; controls and diagnostics support it instead of dominating it.
- Cross-device continuity: mobile and desktop use one mental model, with layout adaptation instead of separate products.
- Feature completeness: Call, Files, Games, Stats, Participants, Settings, devices, reactions, screen share, and lifecycle states remain available.
- Operational quality: connected, joining, waiting, degraded, reconnecting, failed, and ended states are all designed.
- Validation quality: screenshots and E2E cover the real workflows, not only the happy path.

This should be treated as a product redesign with implementation phases, not as an MVP. A phase can be delivered incrementally, but each phase must leave the feature coherent and usable.

## North Star Experience

The ideal experience:

- A user accepts or joins a media session and lands in one obvious session surface.
- The center of the screen is the session itself: video, audio state, screen share, participants, or the relevant empty state.
- The user always knows who/what they are connected to, whether the session is healthy, and what controls are available.
- Secondary tools are close but not noisy: files, games, stats, participants, and settings live in predictable sections.
- Mobile feels designed first, not like desktop windows stacked vertically.
- Desktop feels more powerful than mobile, not more fragmented.
- The retro Windows 98 language stays, but it becomes more deliberate: compact, crisp, and composed.

## Feature Preservation Contract

The redesign can be disruptive visually and structurally, but these capabilities must remain intact.

P2P must preserve:

- Invite creation, accept, decline, pending, connected, and ended states.
- Audio call, video call, screen share, mute, camera toggle, device selection, reactions, mini/expanded call behavior where still relevant.
- P2P file transfer.
- P2P games.
- P2P statistics.
- Existing WebRTC media hook lifecycle and test-critical selectors unless intentionally migrated with tests.

Conference must preserve:

- Prejoin device and layout choices.
- Join, leave, end/close room, lock/moderation controls where applicable.
- Audio, video, screen share, mute/camera toggles, reactions, raise hand, participants, participant moderation.
- Stats and connection diagnostics.
- Existing group call lifecycle, SFU/WebRTC behavior, and hook mounting expectations.

Shared capabilities must preserve:

- Keyboard and pointer access.
- Touch-safe controls.
- Internationalized copy paths.
- Existing testability through stable test IDs or deliberate replacements.
- Retro visual identity.

## Recommended Product Direction

Create a shared Media Session Console language and apply it to both P2P and conference.

The console should have:

- Session header: protocol, target/channel, connection state, participant/track count, duration/quality, primary close/leave.
- Media stage: the main video/audio/screen-share area, with empty states tuned for the current session type.
- Compact command bar: mute, camera, share, participants/peer, stats, reactions, end.
- Mode navigation: the main sections available in the current session.
- Inspector area: desktop side panel, mobile tab/sheet.
- Consistent stats: health summary, transport details, peer details, advanced metrics.
- Consistent setup/prejoin: preview, intent, devices, advanced options.

P2P should not default to four separate top-level windows on mobile. The recommended model is one P2P Session Console with sections for Call, Files, Games, and Stats. On desktop, those sections can become docked panels or detachable windows later, but the default should still feel like one coherent session.

Conference should keep its single-surface direction, but adopt the same compact header, control sizing, stats pattern, and prejoin hierarchy as P2P.

## Target Screen Model

### P2P Session Console

Primary sections:

- Call: media stage, peer state, local controls, reactions, screen share, devices.
- Files: transfer queue, incoming/outgoing files, progress, retry/cancel, peer availability.
- Games: available games, active game session, invite state, turn/status feedback.
- Stats: health summary, transport metrics, peer/browser/device details, advanced diagnostics.

Mobile behavior:

- After connect, open the P2P console directly.
- Default to Call.
- Use a compact top header and bottom command/navigation area.
- Files, Games, and Stats should be reachable through tabs or a sheet, not through hidden taskbar/window discovery.

Desktop behavior:

- Open one coherent P2P console by default.
- Allow richer layout: stage plus inspector, or section tabs plus optional docked panels.
- Detachable windows can remain an advanced desktop affordance later, but they should not be required to use the feature.

### Conference Session Console

Primary sections:

- Call: stage/grid, local controls, reactions, screen share, layout controls.
- People: participant list, roles, raised hands, media state, moderation actions.
- Stats: room health, server/SFU health, peer diagnostics, advanced metrics.
- Settings: devices, layout, self view, call options.

Mobile behavior:

- Open the call surface after join, as it already does, but reduce competing chrome.
- Keep Call as the main surface.
- Move People, Stats, and Settings into predictable tabs or sheets.
- Avoid showing participant panel and dense stats as always-on fixed chrome in narrow viewports.

Desktop behavior:

- Preserve the strong single-surface model.
- Keep participants as a side panel when space allows.
- Use stats as a docked inspector with a summary-first layout.
- Make advanced panels feel integrated, not like separate debug windows.

## Visual and Interaction Standards

The redesign should raise the desktop and mobile UI together.

- Icon glyphs should generally be 14-20px, not 32px, unless they are decorative empty-state illustrations.
- Touch/click targets should remain large enough: usually 36-44px depending on context.
- Header rows should be compact and information-dense without becoming noisy.
- Primary media content should own the largest area.
- Toolbars should use stable dimensions so states do not resize the layout.
- Buttons should align consistently and use icon-first affordances where meaning is familiar.
- Stats should use a "status summary first, raw details later" hierarchy.
- Empty states should explain the state without becoming large illustrations that crowd the workspace.
- Mobile should not require horizontal discovery for core session actions.
- Desktop should not rely on overlapping windows for basic operation.

## Concrete Implementation Blueprint

This is the implementation-level plan. The product direction above says where the experience should land; this section says how to get there in this codebase.

### Current File Map

P2P surfaces:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`
  - Current implementation renders the unified `P2PSessionConsole` inside `p2p-call-window`.
  - The previous separate `p2p-stats-window`, `p2p-games-window`, and `p2p-files-window` surfaces were removed from the primary template path.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/p2p_session_events.ex`
  - Owns P2P event routing, console section selection, window open/close behavior, mobile console opening, and island `send_update/2`.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/p2p_session_console.ex`
  - New unified P2P console shell. It composes Call, Files, Games, and Stats without taking over the lifecycle state from the existing islands.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/p2p_media_island.ex`
  - Owns call/media state and renders `Components.UI.P2P.CallPanel`.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/p2p_file_island.ex`
  - Owns file transfer state. Must remain mounted during the whole connection because `FileTransferHook` and the data channel depend on it.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/p2p_game_island.ex`
  - Owns game panel state. Today it mounts only while the Games window is open.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/p2p/call_panel.ex`
  - Current P2P call UI.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/p2p/setup_dialog.ex`
  - Current P2P setup dialog.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/lobby/file_panel.ex`
  - Current P2P file UI.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/lobby/game_panel.ex`
  - Current P2P game UI.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/lobby/lobby_network_panel.ex`
  - Current P2P stats UI.

Conference surfaces:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/app/chat_live.html.heex`
  - Currently renders `group-call-window` and `group-call-stats-window`.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/group_call_events.ex`
  - Owns group call event routing and window behavior.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/group_call_panel.ex`
  - Live component wrapper for the conference panel. The WebRTC hook is mounted inside a stable ignored subtree and must survive normal LiveView patches.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/panel.ex`
  - Current conference call UI.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/pre_join_dialog.ex`
  - Current conference prejoin dialog.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/stats_panel.ex`
  - Current conference stats UI.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/video_surface.ex`
  - Conference video/stage surface.
- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/group_call/layout_controls.ex`
  - Conference layout controls.

High-value tests already present:

- `e2e/tests/chat-p2p.spec.ts`
- `e2e/tests/chat-group-call.spec.ts`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_media_island_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_file_island_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_game_island_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs`
- `apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/group_call/pre_join_dialog_test.exs`

### Core Technical Decision

The redesign introduces a shared media-session product system with a single product surface per active media session.

For P2P, use the existing `p2p-call` / `p2p-call-window` as the initial primary console container. This avoids adding a fifth P2P window and preserves the most important existing lifecycle expectation: the media island is already always mounted while the session is joined. Inside that window, the UI becomes the P2P Session Console with sections for Call, Files, Games, and Stats.

The old standalone P2P Files/Games/Stats window model is no longer represented as a live product path. Files, Games, and Stats are sections of the main P2P console; shortcuts select a section through `p2p_console_select`.

For conference, keep the existing `group-call` / `group-call-window` as the only conference container. Stats, people, and settings are responsive sections inside that window; the former `group-call-stats` dock/window path has been removed.

### New Shared Components

Create a small presentational layer under:

- `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/media_session/`

Initial components:

- `shell.ex`
  - Shared frame for header, mode navigation, main stage, command bar, and inspector.
- `header.ex`
  - Protocol icon, peer/channel label, state, duration, quality, participant/track badges, end/leave slot.
- `command_bar.ex`
  - Compact button pattern, icon sizing, danger action treatment, active/pressed states.
- `mode_nav.ex`
  - P2P and conference section navigation. Mobile-friendly with clear scroll/overflow affordance only if needed.
- `metric_badge.ex`
  - Connection quality, tracks, participants, duration, file/game activity.
- `inspector.ex`
  - Desktop side panel and mobile sheet/tab wrapper.
- `setup_layout.ex`
  - Shared setup/prejoin layout for P2P setup and conference prejoin.

These should be presentational components first. They should not own WebRTC, file transfer, game, or stats state.

Status after implementation pass 2: shared primitives remain a recommended next step, but the product pattern is now proven in both surfaces. P2P uses `P2PSessionConsole` sections for Call/Files/Games/Stats. Conference uses explicit Call/People/Stats/Settings sections inside `GroupCall.Panel`, with desktop inspectors and mobile focused modes.

### P2P Implementation Sequence

1. Add shared media-session components with no behavior change.
   - Replace only repeated visual primitives where safe.
   - Keep current P2P windows and tests passing.

2. Add P2P console routing state.
   - Add an assign such as `p2p_console_section`, with values `:call`, `:files`, `:games`, `:stats`.
   - Add events such as `p2p_console_select` or reuse existing open events to set the section.
   - Existing actions `p2p_open_call`, `p2p_open_stats`, file offer, game proposal, and stats docking should select the correct console section.

3. Make mobile P2P open the console after connect.
   - Change the mobile branch that currently skips `burst_windows/1`.
   - On mobile, open/focus `p2p-call` and select `:call`.
   - Update the post-connect chat copy so it does not promise that separate windows will open on mobile.

4. Build `P2PSessionConsole`.
   - Proposed file: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/chat_live/components/p2p_session_console.ex`.
   - It composes existing islands and stats into one product surface.
   - Call section renders `P2PMediaIsland`.
   - Files section renders `P2PFileIsland`.
   - Games section renders `P2PGameIsland`.
   - Stats section renders `lobby_network_panel`.

5. Preserve P2P lifecycle rules.
   - `P2PMediaIsland` remains mounted while the session is joined.
   - `P2PFileIsland` remains mounted while the session is joined, even when Files is not the visible section.
   - `P2PGameIsland` is now mounted inside the console while the session surface exists, so game proposals/results can route into the Games section without depending on a separate window mount.
   - `lobby_network_panel` remains server-rendered from `@p2p_session.stats`.

6. Convert the default desktop behavior.
   - Stop defaulting to a visible burst of separate P2P windows.
   - Default to the P2P console.
   - Keep Files/Games/Stats taskbar/menu actions as section shortcuts or detach affordances.

7. Redesign P2P setup.
   - Status: first pass completed in implementation pass 1.
   - Preview and send action are dominant.
   - Topology/privacy are compact supporting details.
   - Devices and media preferences remain explicit.

8. Update P2P tests.
   - Update E2E expectations that currently assume all P2P windows open as separate default windows.
   - Add mobile post-connect coverage proving the console is visible and operable.
   - Keep file transfer and game lifecycle tests focused on behavior, not old window fragmentation.

### Conference Implementation Sequence

1. Apply shared visual primitives inside `GroupCall.Panel`.
   - Header becomes `MediaSession.Header`.
   - Main controls become `MediaSession.CommandBar`.
   - Stats/participants/settings entry points become `MediaSession.ModeNav` or inspector actions.
   - Keep `group-call-webrtc` stable and do not move ignored WebRTC DOM casually.
   - Status: pass 2 implemented the product behavior locally in `GroupCall.Panel`; extraction to shared `MediaSession.*` components is still pending.

2. Refactor active conference layout.
   - Desktop: stage plus participants side panel by default, stats as inspector/dock.
   - Mobile: stage first, compact command bar, People/Stats/Settings through tabs or sheet.
   - Remove always-visible narrow participant column on mobile if it competes with stage visibility.
   - Status: pass 2 completed the responsive section model. Mobile Call focuses the stage, People owns the participant list, Settings owns layout controls, and desktop keeps stage plus inspector where space allows.

3. Refactor conference stats.
   - Keep `group_call_stats_panel` data intact.
   - Add summary-first layout: quality, participants, tracks, ICE/signaling state first.
   - Advanced server/runtime/peer rows become progressive detail.
   - Status: pass 3 added a summary-first top section while preserving the existing advanced fieldsets. Pass 33 removed the separate dock/window path; Stats now renders only inline inside `group-call`.

4. Redesign conference prejoin.
   - Status: first pass completed in implementation pass 1.
   - Preview, join intent, devices, layout, and self view remain explicit.
   - Topology visual weight is reduced.
   - The hierarchy now matches P2P setup.

5. Update conference tests.
   - Keep `chat-group-call.spec.ts` behavior coverage.
   - Adjust selectors only where the UI model changes intentionally.
   - Add mobile screenshot coverage for Call, People, Stats, Settings.
   - Status: pass 2 added E2E assertions for Settings, People, Call, and Stats section selection in the existing conference visual-polish spec; temporary screenshot capture was used for fresh evidence and then removed.

### Exact Validation Gates

After shared primitive work:

- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/group_call/pre_join_dialog_test.exs`
- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs`
- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_media_island_test.exs`
- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_file_island_test.exs`
- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_game_island_test.exs`

After P2P console work:

- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs`
- `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts`
- Fresh screenshots: P2P desktop setup, desktop console Call/Files/Games/Stats, mobile setup, mobile connected console Call/Stats.

After conference alignment:

- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs`
- `rtk npm --prefix e2e test -- --project=chromium tests/chat-group-call.spec.ts`
- Fresh screenshots: conference desktop prejoin, desktop Call, desktop Settings, mobile prejoin, mobile Call, mobile People, mobile Settings.

Final regression:

- `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
- Screenshot comparison against the fresh audit captures.
- Manual visual inspection at mobile and desktop widths.

### Implementation Pass 1 - Completed 2026-07-16

Delivered:

- P2P now opens one `P2P Session Console` inside `p2p-call-window` instead of defaulting to separate Call/Files/Games/Stats windows.
- P2P mobile no longer skips the media surface after connect; the console opens on mobile and defaults to Call.
- P2P menu/start/status/taskbar actions now focus the console and select Call, Files, Games, or Stats.
- Incoming file offers and game activity route to their matching console sections.
- The Call, Files, and Games islands gained opt-in flags so ending/canceling one activity does not close the whole console.
- The P2P taskbar now exposes one session entry instead of multiple feature-window entries.
- P2P help copy now describes the console model instead of promising separate session windows.
- Conference received the first visual alignment pass: smaller icons, smaller control targets where appropriate, tighter bottom bar, and a mobile participant layout that stacks below the stage.
- P2P Stats mobile was corrected after screenshot validation found the two-peer network diagram clipping horizontally. The mobile diagram now stacks local peer, link, and remote peer.
- P2P setup and conference prejoin now share the same entry hierarchy: preview first, session intent, media defaults, route/topology, layout where relevant, and devices.
- New desktop/mobile entry screenshots confirm the setup/prejoin surfaces keep primary controls reachable and avoid horizontal overflow.

Validation completed:

- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/help_live_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/help_system_feature_test.exs --include liveview_feature`
  - 87 tests, 0 failures.
- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_media_island_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_file_island_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_game_island_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs`
  - 20 tests, 0 failures.
- `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 25 tests, 0 failures.
- Temporary screenshot capture specs passed with desktop/mobile overflow checks, then were removed.

Learnings:

- The critical P2P problem was not media logic; it was reachability and information architecture. Once all sections shared one console, mobile and desktop could use the same mental model.
- Always-mounted feature islands are safer than on-demand windows for this session model, but close/cancel behavior needs explicit flags so feature lifecycles do not accidentally close the console.
- Stats need responsive rules separate from normal desktop metrics. The old P2P stats diagram had CSS scoped to `#p2p-stats`; after moving Stats into the console, that protection no longer applied.
- Conference already had the better product shape. Its biggest immediate gain came from reducing chrome weight and letting mobile stack participants under the stage.

Remaining work:

- Extract shared media-session primitives once the second surface confirms the final pattern.
- Turn conference People/Stats/Settings into the same explicit section/inspector language used by P2P. Completed in implementation pass 2.
- Make stats summary-first across P2P and conference; raw metrics should remain available but not dominate mobile. First pass completed in implementation pass 3.
- Add permanent mobile screenshot/overflow assertions for P2P console sections and conference sections once the layout stabilizes.

### Implementation Pass 2 - Completed 2026-07-16

Delivered:

- Conference now has explicit Call, People, Stats, and Settings section navigation inside `GroupCall.Panel`.
- `group_call_events.ex` now owns `console_section` state for the conference layout and normalizes it with the rest of the layout model.
- Call remains the primary section. On desktop it can still show the participants inspector beside the stage; on mobile it now focuses the media stage instead of inheriting the desktop sidebar.
- People is now the participant inspector section. On mobile it becomes the focused participant-management view; on desktop it keeps the side-inspector behavior.
- Settings is now a real conference section with layout controls and compact summaries for Layout, People visibility, and Self view.
- Stats uses the same section affordance while preserving the existing `group-call-stats-window` dock behavior. This avoids breaking the current diagnostics feature while aligning the entry point with the new console language.
- The conference layout rail was compacted on mobile by making the workspace grid reserve only content height for the rail and the rest of the space for the active section.
- The WebRTC/media DOM remains mounted; section changes hide or show surrounding UI without tearing down the call.
- The E2E visual-polish test now asserts Settings, People, Call, and Stats section selection, and its overflow audit ignores elements that are intentionally hidden by responsive section state.
- Fresh implementation screenshots now cover desktop Call/Settings and mobile Call/People/Settings.

Validation completed:

- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 33 tests, 0 failures.
- `rtk npm --prefix e2e test -- --project=chromium tests/chat-group-call.spec.ts`
  - 19 tests, 0 failures.
- `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 25 tests, 0 failures.
- `rtk npm --prefix e2e test -- --project=chromium tests/chat-group-call.spec.ts -g "failed media recovery offers"`
  - 1 test, 0 failures. This was rerun after stabilizing the synthetic recovery-state action against the real hook's connected-state updates.
- Temporary conference screenshot capture spec passed, generated the new desktop/mobile section screenshots, and was removed.

Learnings:

- The conference surface did not need a new top-level window. The right move was to make the existing `group-call-window` behave like a session console internally.
- Desktop and mobile can share the same section vocabulary, but not the same always-visible density. Desktop can keep inspectors open; mobile needs each section to become a focused mode.
- Keeping Stats as the existing docked window is a useful compatibility step, but the next product-level improvement is still a summary-first stats inspector shared with P2P.
- Screenshot review caught a real mobile layout issue that tests alone did not express: the layout rail was reserving too much vertical space. The fix was in grid track sizing, not more conditional rendering.

Remaining work:

- Continue extracting shared `MediaSession.*` primitives. The first cut (`SectionNav` and `SummaryCard`) is complete.
- Continue refining Stats with progressive disclosure for advanced raw metrics. The first summary-first pass is complete.
- Add permanent screenshot assertions for the sectioned conference states and P2P console sections if visual regression coverage becomes part of the normal suite.

### Implementation Pass 3 - Completed 2026-07-16

Delivered:

- P2P Stats now opens with a compact Health, Latency, Media, and Data summary before the Network/Audio/Video/Game/File tab details.
- Conference Stats now opens with a compact Health, Latency, Media, and Room summary before Server, Server runtime, Server peers, Browser connection, Audio, Video, and Browser summary details.
- Existing raw metrics, tabs, fieldsets, test IDs, and data rendering remain available. This was an information-hierarchy change, not a data-model change.
- Conference Stats on mobile now focuses the `group-call-stats` window when the user taps the Stats section, instead of leaving the Stats tab active while the actual stats window remains hidden in the stacked desktop.
- P2P Stats summary copy was tightened so mobile cards do not truncate core labels.
- Fresh implementation screenshots now cover P2P desktop/mobile Stats and conference desktop/mobile Stats.

Validation completed:

- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs`
  - 1 test, 0 failures.
- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 33 tests, 0 failures.
- Temporary stats screenshot capture spec passed, generated the updated Stats screenshots, and was removed.

Learnings:

- Summary-first stats can be added without weakening diagnostics, as long as the raw fieldsets stay intact below the summary.
- Mobile window focus matters as much as rendering. The Stats section was technically selected, but in stacked mode the user still needed the stats window focused.
- The P2P stats sample can lag the visible media state because it reflects browser `getStats()` samples, not just UI call state. The UI should keep reporting the measured state rather than inventing activity.

### Implementation Pass 4 - Completed 2026-07-17

Delivered:

- Added `RetroHexChatWeb.Components.UI.MediaSession.SectionNav` as the shared section-navigation primitive for media-session surfaces.
- Added `RetroHexChatWeb.Components.UI.MediaSession.SummaryCard` as the shared summary-first stats card primitive.
- Migrated `P2PSessionConsole` from local section buttons to `SectionNav`.
- Migrated `GroupCall.Panel` from local section buttons to `SectionNav`.
- Migrated P2P Stats and Conference Stats summary cards to `SummaryCard`.
- Kept all state, event names, test IDs, WebRTC hooks, file/game lifecycles, stats data, and diagnostic details owned by their original surfaces.

Validation completed:

- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 57 tests, 0 failures.
- `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 25 tests, 0 failures.

Learnings:

- The first useful shared layer is presentational, not behavioral. `SectionNav` and `SummaryCard` remove duplication without moving session state or lifecycle ownership.
- The shared primitive must preserve per-surface details: P2P and conference need different test ID prefixes, min widths, borders, and tone class mappings.
- Header, command bar, and inspector extraction should be next, but only after keeping the same rule: no shared component should own media or feature lifecycle.

### Implementation Pass 5 - Completed 2026-07-17

Delivered:

- Added `RetroHexChatWeb.Components.UI.MediaSession.Header` as the shared header shell for media-session surfaces.
- Migrated the P2P session console header to `MediaSession.Header` while keeping P2P-specific status metadata, stats/end actions, labels, and events local.
- Migrated the conference full header and compact mini header to `MediaSession.Header` while preserving moderation actions, media controls, status announcers, test IDs, and mini-mode behavior.
- Kept the shared component presentational only: icon, title, metadata slot, and actions slot. It does not own WebRTC state, lifecycle events, feature permissions, or media controls.

Validation completed:

- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 57 tests, 0 failures.
- `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 25 tests, 0 failures.

Learnings:

- Headers are safe to unify only when the action slot remains owned by each feature. P2P and conference have different control semantics even when the visual chrome is now shared.
- The compact conference header needs the same shared structure as the full header; otherwise mini mode becomes a second visual system.
- The next extraction candidates are command bars and inspector shells, but only if their state and event ownership stays local to each surface.

### Implementation Pass 6 - Completed 2026-07-17

Delivered:

- Added `RetroHexChatWeb.Components.UI.MediaSession.IconButton` as the shared icon-only action button for media-session surfaces.
- Migrated conference call controls through the shared button primitive while preserving the existing `group_call_button` call sites and all moderation/media events.
- Migrated P2P call controls through the shared button primitive while preserving data attributes consumed by `LobbyMediaHook`.
- Migrated P2P call header to `MediaSession.Header`, aligning it with the P2P console and conference headers.
- Reduced P2P call-panel operational icons from oversized `h-8 w-8` usage to the shared `h-4 w-4` control language. Large empty-state illustrations and reaction badge containers remain intentionally larger.
- Fixed the P2P idle-state icon that was larger than its own container.

Validation completed:

- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 57 tests, 0 failures.
- `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 25 tests, 0 failures.

Learnings:

- Button unification is safe when the primitive owns only chrome and ARIA. The data attributes used by media hooks must remain on the caller.
- Reducing icon size without changing event ownership gives a large visual win with low lifecycle risk.
- The remaining command-bar work is mostly container-level composition and participant/action menus, not core media behavior.

### Implementation Pass 7 - Completed 2026-07-17

Delivered:

- Migrated conference reaction buttons to `MediaSession.IconButton`.
- Migrated conference participant action menu buttons to `MediaSession.IconButton`, including focus, pin, allow-to-speak, audio/video/screen moderation, and remove participant.
- Migrated raised-hand queue allow-to-speak actions to `MediaSession.IconButton`.
- Preserved every participant `phx-click`, `phx-value-participant-id`, `data-testid`, title/label source, and pressed state.
- Left passive status indicators as badges rather than buttons.

Validation completed:

- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 57 tests, 0 failures.
- `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 25 tests, 0 failures.

Learnings:

- Participant menus can share chrome safely when the menu itself keeps all permission checks and event routing.
- Passive indicators should not be forced into the action-button primitive; they have different semantics and should remain visually related but non-interactive.
- The media-session primitive layer now covers section navigation, headers, summary cards, and icon actions. Remaining extraction should focus on larger shells only when it removes real duplication.

### Implementation Pass 8 - Completed 2026-07-17

Delivered:

- Added `RetroHexChatWeb.Components.UI.MediaSession.CommandBar` as the shared toolbar/group shell for media-session action containers.
- Migrated P2P start-media controls, active media controls, view rail, window controls, layout controls, and reaction drawer containers to `CommandBar`.
- Migrated conference view rail, bottom media controls, reaction controls, and participant action dropdown containers to `CommandBar`.
- Migrated conference `LayoutControls` to use `CommandBar` and `IconButton`.
- Migrated conference screen-share control to `IconButton` while preserving the direct user-gesture data attribute used by the WebRTC hook.
- Kept all command events, `phx-value-*` payloads, test IDs, hook data attributes, and permission checks in their owning feature modules.

Validation completed:

- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 57 tests, 0 failures.
- `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 25 tests, 0 failures.

Learnings:

- A command-bar primitive is useful only when it stays as a shell. The browser media hooks still depend on caller-owned data attributes and real click targets.
- The same `CommandBar` can cover horizontal mobile bars, desktop rails, dropdown toolbars, and grouped view controls through class overrides.
- Remaining polish should focus less on repeated button chrome and more on larger inspector/surface composition.

### Implementation Pass 9 - Completed 2026-07-17

Delivered:

- Added `RetroHexChatWeb.Components.UI.MediaSession.ActionButton` as the shared labelled action button for media-session alerts and compact command areas.
- Migrated conference retry/leave actions in error and warning states to `ActionButton`.
- Aligned those alert actions with the shared 32px media-session control rhythm instead of the older `h-10` manual buttons.
- Preserved `phx-click` handlers, labels, danger tone, and test IDs for recovery and leave flows.

Validation completed:

- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 57 tests, 0 failures.
- `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 25 tests, 0 failures.

Learnings:

- Text actions need a separate primitive from icon-only controls; forcing them into `IconButton` would hurt clarity.
- The alert/recovery paths are part of the product surface, not edge chrome. Aligning them visually helps both mobile and desktop without touching recovery behavior.
- The shared media-session layer now covers icon actions, text actions, command bars, headers, section navigation, and summary cards.

### Implementation Pass 10 - Completed 2026-07-17

Delivered:

- Added `RetroHexChatWeb.Components.UI.MediaSession.InspectorPanel` as the shared shell for media-session side panels and section inspectors.
- Migrated conference Settings to `InspectorPanel`, preserving the settings view hierarchy and layout controls.
- Migrated conference Participants to `InspectorPanel`, preserving desktop sidebar visibility, mobile People-section visibility, participant list role, participant list test ID, raised-hand queue, and all moderation rows.
- Kept all participant events, permission checks, layout events, and row rendering local to `GroupCall.Panel`.

Validation completed:

- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 57 tests, 0 failures.
- `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 25 tests, 0 failures.

Learnings:

- Inspector extraction is safe when the body slot keeps the original list roles, test IDs, and eventful rows.
- Settings and Participants share the same product shell even though their contents are different. This makes desktop sidebar and mobile section behavior feel like one system.
- Stats inspectors should be reviewed next, but their scroll-preservation hooks need to remain on the element that owns scroll state.

### Implementation Pass 11 - Completed 2026-07-17

Delivered:

- Added `RetroHexChatWeb.Components.UI.MediaSession.StatusHeader` as the shared identity/status/facet header for media-session inspectors and stats panels.
- Migrated conference Stats header to `StatusHeader`, preserving browser state, room status, and `group-call-stats-participants`.
- Migrated P2P Stats session header identity/status/facet row to `StatusHeader`, preserving the outer stats session wrapper, summary cards, facet test IDs, and `PreserveScrollHook` ownership.
- Left stats summary grids, tabs, diagnostics, and metric rows in their owning stats components.

Validation completed:

- `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 57 tests, 0 failures.
- `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 25 tests, 0 failures.

Learnings:

- Stats can share the top status language without moving scroll preservation, tabs, or diagnostics.
- `PreserveScrollHook` should remain on the stats root that already owns scroll state; shared components should sit inside it unless a deeper refactor explicitly validates scroll behavior.
- The stats surfaces now share header, summary-card, and action primitives while keeping metric ownership local.

### Implementation Pass 12 - Completed 2026-07-17

Delivered:

- Ran a fresh Playwright visual QA capture after the shared primitive refactors.
- Generated updated screenshots in `docs/plans/screenshots/media-session-visual-qa/` for:
  - P2P desktop: Call, Files, Games, Stats, Mini.
  - P2P mobile: Call, Stats.
  - Conference desktop: Prejoin, Call, People, Settings, Stats, Mini.
  - Conference mobile: Call, People, Settings, Stats.
- Fixed a P2P desktop regression found in screenshots: switching from Call to Files/Games/Stats forced `p2p-call` into a narrow `460px` geometry. The console now preserves maximized/default geometry unless it is explicitly expanding from mini mode.
- Updated the P2P mini-to-stats geometry to use the unified console size (`760x520`) instead of the old narrow stats-window size.
- Fixed a conference mobile visual issue found in screenshots: inline reaction buttons pushed the Leave button onto a second row. Reactions now use a compact drawer while preserving every reaction button, icon, data attribute, and test ID.
- Updated the group-call E2E reaction flow to open the reaction drawer before clicking a reaction.

Validation completed:

- Temporary visual capture spec:
  - `rtk npm --prefix e2e test -- --project=chromium tests/media-session-visual-qa.tmp.spec.ts`
  - 2 tests, 0 failures.
  - Spec removed after screenshots were captured.
- Focused P2P flow:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs --include liveview_feature`
  - 23 tests, 0 failures.
- Full focused media suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 57 tests, 0 failures.
- Group-call E2E after reaction drawer change:
  - `rtk npm --prefix e2e test -- --project=chromium tests/chat-group-call.spec.ts`
  - 19 tests, 0 failures.
- Full P2P + conference E2E:
  - `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 25 tests, 0 failures.

Learnings:

- The screenshot pass caught issues that functional tests alone did not: stale P2P geometry and mobile command-bar wrapping.
- Preserving default/maximized desktop geometry is important for the unified P2P console. Section changes should not behave like old detached windows.
- Reactions are a secondary control group and fit better behind a compact drawer on mobile; keeping the same drawer on desktop maintains one interaction model.
- Visual QA should remain part of every major media-session pass, especially after shell/primitive extraction.

### Implementation Pass 13 - Completed 2026-07-17

Delivered:

- Upgraded the shared `MediaSession.SectionNav` primitive so P2P and conference section tabs expose a consistent horizontal-scroll cue instead of relying on invisible overflow.
- Added a stable `data-scroll-cue="horizontal"` contract and shared item class to the section navigation markup while preserving all existing labels, events, `phx-value-section` values, and test IDs.
- Added mobile-only Win98-style left/right cue gutters in `retrohex.css`, with scroll snapping and thin retro scrollbars for the shared media-session nav.
- Kept the cue in the shared primitive rather than solving P2P and conference separately, so future media-session tabs inherit the same behavior.
- Added permanent P2P and conference E2E assertions for the mobile section-nav cue contract at `390x844`, covering both the `data-scroll-cue` markup and the CSS `::before` / `::after` indicators.
- Generated fresh mobile screenshots:
  - `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-section-nav.png`
  - `docs/plans/screenshots/media-session-visual-qa/conference-mobile-section-nav.png`

Validation completed:

- New focused component test:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/media_session/section_nav_test.exs`
  - 1 test, 0 failures.
- Full focused media suite with the new component test:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/media_session/section_nav_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 58 tests, 0 failures.
- Temporary Playwright visual QA for mobile section navigation:
  - `rtk npm --prefix e2e test -- --project=chromium tests/media-session-section-nav-visual.tmp.spec.ts`
  - 1 test, 0 failures.
  - Spec removed after screenshots were captured.
- Full P2P + conference E2E:
  - `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 25 tests, 0 failures.
- Full P2P + conference E2E after adding permanent cue assertions:
  - `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 25 tests, 0 failures.

Learnings:

- The section-tab problem belongs in the shared primitive. Patching only conference would have left P2P with a subtly different navigation model.
- Mobile tabs need both mechanical scrollability and a visible affordance. The cue gutters make hidden overflow discoverable without adding a second navigation system.
- Desktop should keep the cleaner full-width tab presentation, while mobile gets explicit cues only at the constrained breakpoint.

### Implementation Pass 14 - Completed 2026-07-17

Delivered:

- Hardened the shared `MediaSession.Header` layout for long peer/channel names by making the title block `flex-1 min-w-0` beside any header actions.
- Added a focused `MediaSession.Header` component test to preserve the flexible-title contract.
- Added permanent P2P and conference E2E header audits that run inside real media-session roots and fail if any header overflows or creates horizontal scroll.
- Stressed the P2P connected flow with near-maximum nicknames and the conference visual flow with a long channel name.
- Moved P2P call duration and peer media-state indicators out of the header actions slot and into the metadata row. They were informational, not commands, and were compressing the call title on mobile.
- Generated fresh long-header screenshots:
  - `docs/plans/screenshots/media-session-visual-qa/p2p-desktop-long-header.png`
  - `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-long-header.png`
  - `docs/plans/screenshots/media-session-visual-qa/conference-desktop-long-header.png`
  - `docs/plans/screenshots/media-session-visual-qa/conference-mobile-long-header.png`

Validation completed:

- Focused header + P2P call-panel component tests:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/call_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/media_session/header_test.exs`
  - 8 tests, 0 failures.
- Full focused media suite with header and call-panel coverage:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/media_session/header_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/media_session/section_nav_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/call_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 66 tests, 0 failures.
- Temporary Playwright long-header visual QA:
  - `rtk npm --prefix e2e test -- --project=chromium tests/media-session-long-header-visual.tmp.spec.ts`
  - 1 test, 0 failures.
  - Spec removed after screenshots were captured.
- Full P2P + conference E2E:
  - `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 25 tests, 0 failures.

Learnings:

- The long-name checkpoint exposed a real composition issue, not a pure overflow bug: P2P call duration and peer-state indicators looked like header actions but behaved as status metadata.
- Shared header flex behavior should make the title area elastic by default; individual surfaces should not have to rediscover truncation rules.
- P2P and conference can keep the same header system, but P2P's call-level status needs to stay lightweight because it sits above a dense media stage and command bar.

### Implementation Pass 15 - Completed 2026-07-17

Delivered:

- Added the missing `768x1024` tablet-ish checkpoint to the real P2P and conference E2E flows.
- P2P now permanently audits the unified console at `768x1024`, `390x844`, and `1280x720` for root size, visible overflow, unintended horizontal scroll, and header stability.
- Conference now permanently audits the active call at `768x1024` before section navigation continues through Settings, People, Call, Stats, and mobile.
- Improved the conference Participants loading state from a bare `Joining...` line into a richer list item with icon, title, and description:
  - Title: `Joining conference`.
  - Detail: participant controls appear once the media connection is ready.
  - Preserves the participant list role and adds `data-testid="group-call-participants-loading"`.
- Generated fresh tablet screenshots:
  - `docs/plans/screenshots/media-session-visual-qa/p2p-tablet-call.png`
  - `docs/plans/screenshots/media-session-visual-qa/p2p-tablet-stats.png`
  - `docs/plans/screenshots/media-session-visual-qa/conference-tablet-call.png`
  - `docs/plans/screenshots/media-session-visual-qa/conference-tablet-people.png`
  - `docs/plans/screenshots/media-session-visual-qa/conference-tablet-settings.png`
  - `docs/plans/screenshots/media-session-visual-qa/conference-tablet-stats.png`

Validation completed:

- Focused conference flow after Participants loading-state change:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 33 tests, 0 failures.
- Temporary Playwright tablet visual QA:
  - `rtk npm --prefix e2e test -- --project=chromium tests/media-session-tablet-visual.tmp.spec.ts`
  - 1 test, 0 failures.
  - Spec removed after screenshots were captured.
- Full P2P + conference E2E after adding permanent tablet assertions:
  - `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 25 tests, 0 failures.
- Full focused media suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/media_session/header_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/media_session/section_nav_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/call_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 66 tests, 0 failures.

Learnings:

- The tablet breakpoint did not expose a structural overflow issue, but it did expose an under-designed loading state in the Participants inspector.
- A large empty inspector should not be a single status word. Even transient states need enough context to feel intentional on tablet and desktop.
- The real E2E suite now covers the three viewport classes from Phase 4: mobile, tablet-ish, and desktop.

### Implementation Pass 16 - Completed 2026-07-17

Delivered:

- Added a real P2P receive-only E2E path: accept invite with microphone and camera off, connect, receive Alice's remote video, and assert Bob has no local audio/video tracks.
- Fixed the product contract for receive-only P2P:
  - `media_mode: "receive"` is now passed into `P2PMediaIsland`.
  - When the peer turns media on, receive-only peers now receive `lobby_media_join` instead of `lobby_media_start_audio` / `lobby_media_start_video`.
  - Audio-mode peers still auto-start mic-only; default video mode keeps matching the peer's active media.
- Registered `lobby_media_join` in the lazy `LobbyMediaHook` server-event list so the join command is not lost while the hook bundle is loading.
- Strengthened the LiveView P2P flow test so the receive-only case proves the actual hook command, not just the domain media state.
- Refined the P2P console layout auditor to focus on the console shell, sections, and headers. Internal toolbars/popovers are still covered by feature assertions, but they are not treated as shell overflow when they intentionally expand.

Validation completed:

- Focused P2P LiveView/component suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_media_island_test.exs --include liveview_feature`
  - 29 tests, 0 failures.
- Full P2P E2E:
  - `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts`
  - 7 tests, 0 failures.
- Full focused media suite after the P2P receive-only contract change:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/media_session/header_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/media_session/section_nav_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/call_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_media_island_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 72 tests, 0 failures.
- Full P2P + conference E2E:
  - `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 26 tests, 0 failures.

Learnings:

- Receive-only cannot be modeled as "try to open media, then fall back if permission fails." It is an explicit user posture and must avoid local capture from the first hook command.
- The setup dialog preview and the connected media hook are different lifecycles. The preview may open temporarily before submit, but accepting receive-only must stop preview capture and join the session without publishing tracks.
- Visual auditors should protect structural shell stability, while feature-specific controls need targeted assertions. Auditing every toolbar as shell overflow produced noise without improving the UX signal.

### Implementation Pass 17 - Completed 2026-07-17

Delivered:

- Added explicit P2P audio-only coverage after the receive-only fix.
- LiveView now proves that accepting with microphone on and camera off sets domain media to `%{audio: true, video: false}` and marks the auto-start complete.
- Playwright now proves the browser-level contract:
  - Bob publishes a local audio track.
  - Bob does not publish a local video track.
  - Bob still receives Alice's remote video.
  - The connected UI shows the audio-call state, mute control, and the enable-camera affordance instead of a camera toggle.
- Fixed the audio-only answerer lifecycle so it joins receive-first, then enables the microphone after remote video is flowing or after a short fallback window. This avoids racing local microphone publication against remote-video receiver setup.
- Improved media-hook resilience while investigating the audio-only edge:
  - `LobbyMediaHook` can now adopt existing remote receivers when it receives the shared `RTCPeerConnection`.
  - `ontrack` no longer depends on `event.streams[0]` being present.
  - The stalled-media watchdog now rechecks receivers before deciding whether recovery is needed.

Validation completed:

- P2P LiveView flow suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs --include liveview_feature`
  - 24 tests, 0 failures.
- Full P2P E2E:
  - `rtk npm --prefix e2e test -- --project=chromium tests/chat-p2p.spec.ts`
  - 8 tests, 0 failures.
- Full focused media suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/media_session/header_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/media_session/section_nav_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/call_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_media_island_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 73 tests, 0 failures.
- Full P2P + conference E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 27 tests, 0 failures.

Learnings:

- Audio-only is a distinct posture from receive-only and video. It needs its own regression coverage because peer video activity must not promote this side into publishing a camera track.
- Audio-only answerers need staged media startup: receive the remote session first, then publish the microphone. Treating audio-only as "video mode without camera" can starve the remote-video path under lazy-hook timing.
- The strongest E2E assertion is the media stream itself plus the visible controls. Copy-level assertions are secondary and can create noise when the UI already exposes the correct state through controls.
- Media hooks must be resilient to lifecycle order. In a LiveView/lazy-hook setup, the `RTCPeerConnection` can already have receivers by the time the media hook attaches its `ontrack` handler.

### Implementation Pass 18 - Completed 2026-07-17

Delivered:

- Added a P2P connection-recovery state to the unified console:
  - Reconnecting and failed states now render an in-console recovery banner instead of only a chat system line.
  - Failed recovery exposes Retry and End actions aligned to the right, matching the conference recovery pattern.
  - The header signal color and label now reflect recovery/failure before generic connected metadata.
- Added coordinated P2P manual retry:
  - `p2p_retry_connection` marks recovery, pushes `lobby_restart` locally, and publishes the restart to the peer.
  - The lazy `LobbyWebRTCHook` now buffers/handles `lobby_restart` and `lobby_renegotiate`.
  - Browser-level recovery can be simulated through `p2p-lobby:recovery-state`, mirroring the existing conference recovery test pattern.
- Stabilized audio-only P2P as a receive-first posture:
  - Audio mode now joins as a receiver on media-hook ready instead of publishing the microphone before peer video is flowing.
  - Added an internal `join_call` media event so the island can mount receiver state without marking local media in the domain.
  - When peer media appears, audio mode auto-starts microphone only; receive mode remains no-capture.
  - The media hook now allows the intended `receiving -> audio` transition, while still preventing duplicate starts.
  - Auto-start commands are guarded by the DOM `data-media-mode`, so an audio-only setup cannot be accidentally promoted into camera publishing by a stale/auto video command.
- Strengthened stalled media recovery:
  - Remote video readiness now checks actual video element frames/dimensions, not only `MediaStreamTrack.muted`.
  - Startup audio-only can request a coordinated `lobby_media_restart` before publishing microphone if remote video negotiated but did not produce frames.
- Added explicit testability signals:
  - `p2p-session-console` exposes `data-p2p-media-mode`.
  - The P2P call surface exposes `data-media-mode`.
  - The P2P E2E asserts the audio-only mode before validating media tracks.

Validation completed:

- P2P LiveView flow suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs --include liveview_feature`
  - 25 tests, 0 failures.
- Full P2P E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts`
  - 9 tests, 0 failures.
- Full focused media suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/media_session/header_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/media_session/section_nav_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/call_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_media_island_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 74 tests, 0 failures.
- Full P2P + conference E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 28 tests, 0 failures.
- Hygiene:
  - `rtk git diff --check`
  - 0 whitespace errors.

Learnings:

- Audio-only is not "video auto-start minus camera". The stable sequence is receiver first, remote video flowing second, microphone publication third.
- A call surface needs an explicit setup-intent attribute. Server state can be correct while an async island or queued auto command still tries to do the wrong thing; the hook should defend the user-selected posture.
- Recovery UX and media recovery are related but not identical. A failed connection needs a visible Retry/End banner; a black startup tile may need a coordinated restart before it becomes a user-facing failure.
- Browser tests should validate both product intent (`data-p2p-media-mode="audio"`) and media reality (remote video track, local audio track, no local video track).

### Implementation Pass 19 - Completed 2026-07-17

Delivered:

- Ran a fine visual QA pass for failed recovery states in both media products.
- Generated fresh screenshots in `docs/plans/screenshots/media-session-visual-qa/`:
  - `p2p-desktop-recovery-failed.png`
  - `p2p-mobile-recovery-failed.png`
  - `conference-desktop-recovery-failed.png`
  - `conference-mobile-recovery-failed.png`
- Added temporary Playwright capture coverage for the pass, then removed the temp spec after the screenshots were captured.
- Validated objective layout constraints while capturing:
  - Top-level media windows fit inside `1280x720` desktop and `390x844` mobile viewports.
  - P2P and conference failed-recovery banners do not create horizontal scroll.
  - Key headers, nav rows, call sections, video grids, and recovery/error surfaces stay inside their media-session roots.

Visual findings:

- P2P desktop:
  - Recovery is clear and prominent.
  - Retry and End actions are aligned to the right.
  - The Call/Files/Games/Stats model remains visible and stable after failure.
  - The media stage intentionally falls back to the offline state after failed recovery.
- P2P mobile:
  - The same desktop pattern holds at phone width.
  - Section tabs expose the horizontal-scroll cue.
  - The recovery text wraps cleanly and actions remain right-aligned without overflow.
- Conference desktop:
  - The failed-recovery state preserves the richer active-call context: video grid, participant panel, controls, and error banner.
  - Retry and Leave actions stay right-aligned in the footer recovery banner.
- Conference mobile:
  - The footer recovery banner remains readable and actionable.
  - The tab cue is visible at the clipped Settings tab edge, so the user gets a scroll affordance.
  - The synthetic video frame text can be cropped inside a tile; this is media content, not product UI text, and does not indicate shell overflow.

Validation completed:

- Recovery visual capture:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/media-session-recovery-visual.tmp.spec.ts`
  - 4 tests, 0 failures.

Decision:

- No product code correction was required from this pass. The recovery state now meets the current playbook for both desktop and mobile: one shared interface language, explicit scroll cues, right-aligned dialog/error actions, no horizontal overflow, and preserved feature context.

Learnings:

- Recovery screenshots are valuable because they exercise UI density differently from normal connected-state screenshots. The banners compress nav, controls, and media content in a way happy-path captures do not.
- P2P and conference intentionally differ after failure: P2P may show the media-offline empty state, while conference keeps the last active room context visible. That difference is acceptable because each state matches its underlying lifecycle.

### Implementation Pass 20 - Completed 2026-07-17

Delivered:

- Added `MediaSession.DiagnosticsGroup`, a shared collapsible diagnostics primitive for stats panels.
  - The summary row stays visible for scanning.
  - Raw metrics remain in the DOM and available on demand.
  - The component owns only presentation; P2P/conference still own data and lifecycle.
- Migrated P2P Stats fieldsets to diagnostics groups:
  - Network/Connection, Audio, Video, Games, and Files now use the shared group.
  - P2P groups remain open by default because each stats tab already scopes the user to one diagnostic domain.
- Migrated Conference Stats fieldsets to diagnostics groups:
  - Server, Server runtime, Server peers, Audio, Video, and Browser summary are compact by default.
  - Browser connection remains open by default because it is the most useful operational diagnostic.
  - Server runtime summary explicitly surfaces peer-connection status so desktop/mobile scans no longer require reading every RTP row.
- Added unit/component coverage for the new primitive and updated existing stats tests to assert the new group contracts.

Screenshots captured:

- `docs/plans/screenshots/media-session-visual-qa/p2p-desktop-stats-diagnostics.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-stats-diagnostics.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-stats-audio-diagnostics.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-desktop-stats-diagnostics.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-mobile-stats-diagnostics.png`

Visual findings:

- P2P desktop:
  - The stats panel keeps the existing summary-first hierarchy and now gives Connection a clearer diagnostics header.
  - The raw connection rows remain visible and do not add horizontal scroll.
- P2P mobile:
  - The Network tab still prioritizes session summary and topology first.
  - The additional Audio-tab screenshot confirms the compact diagnostics group fits at phone width and exposes the rows without overflow.
- Conference desktop:
  - Stats now reads as a concise inspector instead of a stack of equally loud technical fieldsets.
  - Runtime, peers, audio, video, and browser summary are scannable as rows; Browser connection stays expanded for immediate troubleshooting.
- Conference mobile:
  - The stats surface is materially calmer: summary cards first, compact technical groups second, one open diagnostic section.
  - The right-side summaries truncate cleanly without horizontal scroll.

Validation completed:

- Focused component/LiveView stats suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/media_session/diagnostics_group_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 36 tests, 0 failures.
- Temporary stats visual capture:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/media-session-stats-diagnostics-visual.tmp.spec.ts`
  - 2 tests, 0 failures.
- Full P2P + conference E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 28 tests, 0 failures.

Learnings:

- P2P and conference need the same diagnostics language but not the same default expansion. P2P tabs already narrow the scope, while conference stats need collapsed groups to avoid turning mobile into a wall of metrics.
- Pass 21 supersedes the earlier capture assumption for Conference Stats: the canonical user action should target the session section in `group-call-window`; the dedicated stats window remains an explicit desktop dock affordance.
- The P2P Network tab is intentionally topology-heavy on mobile; validating the diagnostics group also needs a tab-specific screenshot such as Audio or Video.

### Implementation Pass 21 - Completed 2026-07-17

Delivered:

- Ran a consistency audit against the core premise: one mobile-first media-session experience, with desktop and mobile differing by density/layout rather than by product model.
- Found and corrected the remaining Conference Stats inconsistency:
  - `Stats` already existed as a conference section.
  - Selecting it still opened/docked `group-call-stats`, which made the tab behave like a second destination instead of the canonical session section.
- Embedded Conference Stats inside `GroupCall.Panel` as `group-call-inline-stats`.
  - Desktop: the Call stage remains visible and Stats appears as the right-side inspector.
  - Mobile: Stats becomes the focused section inside the same `group-call-window`.
- Changed `group_call_console_select` for `stats` to select the section only.
- Removed the explicit desktop dock affordance in Pass 33:
  - The header stats dock button, `group_call_dock_stats`, `group-call-stats` window, and taskbar entry were deleted.
  - The `GroupCall.StatsPanel` id attr remains useful for the inline scroll-preserver id, not for coexistence with a second window.
- Updated E2E and LiveView assertions to make the new contract permanent:
  - Section `Stats` shows `group-call-inline-stats`.
  - No assertion keeps a separate `group-call-stats-window` alive.

Screenshots captured:

- `docs/plans/screenshots/media-session-visual-qa/conference-desktop-inline-stats.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-mobile-inline-stats.png`

Visual findings:

- Desktop now uses one conceptual session surface: Call, People, Stats, and Settings stay in the same conference window. Stats uses the same section navigation as the rest of the conference and appears as a right-side inspector beside the stage.
- Mobile no longer jumps to a separate stats root when the user taps the Stats tab. The Stats section is inside the same conference window, with the same tab row and bottom controls.
- The explicit dock remains useful on desktop, but it is now clearly an advanced/action-button behavior, not the default meaning of the Stats tab.

Validation completed:

- Focused LiveView/component suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/media_session/diagnostics_group_test.exs --include liveview_feature`
  - 36 tests, 0 failures.
- Conference E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-group-call.spec.ts`
  - 19 tests, 0 failures.
- Temporary inline-stats visual capture:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/conference-stats-inline-visual.tmp.spec.ts`
  - 1 test, 0 failures.
- Full P2P + conference E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 28 tests, 0 failures.

Learnings:

- The rule is not "mobile inline, desktop dock". The rule is "section first everywhere"; desktop may add a dock affordance without changing the user's mental model.
- Shared primitives were not enough by themselves. The event routing also had to honor the same product model, otherwise the UI looked unified but navigation still behaved as two systems.
- When the same component can render inline and docked at the same time, hook ids must be caller-owned to avoid duplicate LiveView ids.

### Implementation Pass 22 - Completed 2026-07-17

Delivered:

- Continued the section-first audit after Pass 21 and found one remaining desktop-only split in Conference Stats.
- Removed automatic `group-call-stats` window creation during conference join.
  - Before: desktop join opened `group-call-stats`, minimized it, then opened `group-call`.
  - After: desktop and mobile join only open the primary `group-call` window.
- Kept the explicit stats dock behavior intact:
  - The header stats icon still opens the `group-call-stats-window`.
  - The taskbar entry appears only after that explicit dock action.
- Updated the template comment for `group-call-stats` so the markup documents it as an explicit dock, not a default minimized companion window.
- Updated LiveView and E2E tests to make the new contract permanent:
  - Conference join refutes the stats window and stats taskbar by default.
  - Stats diagnostics are validated after selecting the inline Stats section or after using the explicit dock action.
  - Closing the stats window is tested after the user has explicitly docked it.

Screenshots captured:

- `docs/plans/screenshots/media-session-visual-qa/conference-desktop-no-auto-stats.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-desktop-explicit-stats-dock-after-join.png`

Visual findings:

- Desktop join now starts with one conference surface and no hidden/minimized stats entry in the taskbar.
- The explicit dock action still creates a powerful desktop layout with the conference and Conference Statistics window side by side.
- This aligns desktop and mobile around one product model: Stats is a section first, with dock as an extra desktop affordance.

Validation completed:

- Focused LiveView conference suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 34 tests, 0 failures.
- Conference E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-group-call.spec.ts`
  - 19 tests, 0 failures.
- Temporary visual capture:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/conference-stats-dock-intent.tmp.spec.ts`
  - 1 test, 0 failures.

Learnings:

- "Section first everywhere" also means no background taskbar entries for a feature that already has a canonical in-window section.
- A minimized default window is still a second product surface, even when it is visually quiet.
- Compatibility windows should be created by explicit user actions so desktop power affordances do not leak into the default mobile-first mental model.

### Audit Pass 23 - Completed 2026-07-17

Scope:

- Audited P2P and conference entry points after the section-first migration.
- Checked render roots, menu bar, Start menu, status bar, PM/session badge, taskbar, window manager IDs, LiveView events, tests, CSS, and user-facing help text.
- Goal: identify dead code, ghost compatibility paths, or misleading names that could make future work drift back into two product models.

Current canonical contracts:

- P2P:
  - The only live top-level P2P product surface is `p2p-call-window`, now used as the `P2PSessionConsole`.
  - Menu bar and Start menu actions `p2p_open_files`, `p2p_open_games`, and `p2p_open_stats` route into `open_p2p_console(section)`.
  - Status bar click routes to the P2P console Call section.
  - PM session badge actions route to Call or Stats sections, not separate windows.
  - Search confirmed no live `p2p-stats-window`, `p2p-games-window`, or `p2p-files-window` markup.
- Conference:
  - The canonical surface is `group-call-window`.
  - Stats is available inline as `group-call-inline-stats`.
  - `group-call-stats-window` is still a real explicit desktop dock affordance, with taskbar entry only after the dock action.

Findings:

1. Dead P2P managed window IDs remain.
   - `Windows.@managed` still includes `p2p-games` and `p2p-stats`.
   - `P2PSessionEvents.@p2p_windows` still includes `p2p-stats`, `p2p-files`, `p2p-call`, and `p2p-games`.
   - There is no current template path for `p2p-stats`, `p2p-files`, or `p2p-games`, and the taskbar no longer renders those entries.
   - Risk: stale client/window events can still put ghost IDs into `open_windows`, and future agents may infer that those windows still exist.

2. Dead P2P stats-window CSS remains.
   - `retrohex.css` still has a `#p2p-stats .p2p-diagram...` compact-window block.
   - The live console CSS uses `#p2p-session-console`.
   - Risk: the dead block documents a window that no longer exists and may hide missing desktop responsive rules during future work.

3. P2P stats action naming is misleading.
   - `p2p_dock_stats` no longer docks a stats window; it selects the Stats section and expands the console out of mini mode.
   - `CallPanel` labels this affordance as "Dock statistics".
   - Tests describe "stats docking" even though the product behavior is now section navigation.
   - Risk: code and UX language contradict the single-console model.

4. User-facing help still contains old window language.
   - Cheatsheet/help copy still says "P2P Call Window" in several places.
   - Privacy help still says the "Statistics window" shows relay/privacy indicators.
   - Risk: docs teach a window model while the product now exposes a session console.

5. Some legacy selector names are acceptable for now, but should not expand.
   - `LobbyNetworkPanel` still emits `p2p-stats-*` test IDs. Those are feature-level selectors for the Stats section, not top-level window IDs.
   - Recommendation: do not rename these in the cleanup pass unless a broader selector migration is planned. Avoid creating new top-level `p2p-stats` IDs.

6. Minor template hygiene.
   - `group-call` currently has duplicate `persist_geometry={false}` in `chat_live.html.heex`.
   - The Arcade window comment still compares itself to "P2P Statistics" as if that were a standalone window body.

Recommended cleanup order:

1. Remove ghost P2P window IDs from the managed-window lifecycle.
   - Remove `p2p-games` and `p2p-stats` from `Windows.@managed`.
   - Reduce `@p2p_windows` cleanup to only IDs that can actually be present.
   - Keep `p2p-call` because it is the live console window ID.

2. Remove or migrate dead `#p2p-stats` CSS.
   - Delete the dead block if screenshots remain stable.
   - If desktop Stats still needs compact rules, scope them to `#p2p-session-console` with a name that reflects the console.

3. Rename the P2P stats affordance away from dock language.
   - Replace `p2p_dock_stats` usage with `p2p_open_stats` or a new `p2p_show_stats` event.
   - Change "Dock statistics" labels to "Show stats" / "Open stats".
   - Update tests and E2E wording accordingly.

4. Update help and cheatsheet copy to the session-console model.
   - Use "P2P Session Console" and "Call section" instead of "P2P Call Window" where the shortcut scope is the console.
   - Replace "Statistics window" with "Stats section".

5. Clean minor comments/duplicate attrs.
   - Remove duplicate `persist_geometry={false}` on `group-call`.
   - Update the Arcade comment to avoid referencing standalone P2P Statistics.

Validation for cleanup pass:

- Focused LiveView:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
- Focused component:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/session_badge_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/call_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs`
- E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
- Hygiene:
  - `rtk rg -n "p2p-stats-window|p2p-games-window|p2p-files-window|#p2p-stats|p2p_dock_stats|Dock statistics|Statistics window|P2P Call Window" apps/retro_hex_chat_web/lib apps/retro_hex_chat_web/assets apps/retro_hex_chat_web/test e2e/tests`
  - Any remaining hits should be deliberate feature/test IDs or archived docs, not live product code.

### Implementation Pass 24 - Completed 2026-07-17

Delivered:

- Removed dead P2P window lifecycle entries:
  - Removed `p2p-games` and `p2p-stats` from `Windows.@managed`.
  - Removed the `@p2p_windows` cleanup list from `P2PSessionEvents`; the current P2P console is rendered from `@p2p_session`, not from `open_windows`.
- Removed dead `#p2p-stats` CSS for the old P2P Statistics floating window.
  - The live responsive diagram rules remain scoped to `#p2p-session-console`.
- Replaced misleading P2P stats dock language:
  - Removed the `p2p_dock_stats` event.
  - P2P call controls now use the existing `p2p_open_stats` event.
  - Renamed the test id from `p2p-call-dock-stats` to `p2p-call-open-stats`.
  - Changed the visible/accessible label from "Dock statistics" to "Open stats".
- Updated tests so they validate the current model without naming ghost windows.
  - The P2P connection tests now assert that no P2P server-managed window IDs enter `open_windows`.
- Updated live help and cheatsheet language:
  - "P2P Call Window" became "P2P Session Console".
  - "Statistics window" became "Stats section".
  - Audio/video help now refers to the Call section or focused session console.
- Cleaned the stale Arcade comment that still referenced standalone P2P Statistics.

Validation completed:

- Focused component/help suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/call_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/session_badge_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/keyboard_shortcuts_test.exs`
  - 20 tests, 0 failures.
- Focused P2P + conference LiveView suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 59 tests, 0 failures.
- Full P2P + conference E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 28 tests, 0 failures.

Hygiene:

- Live-code residue search is clean for top-level old P2P window artifacts:
  - `p2p-stats-window`, `p2p-games-window`, `p2p-files-window`
  - `#p2p-stats`
  - `p2p_dock_stats`
  - `Dock statistics`
  - `Statistics window`
  - `P2P Call Window`
  - `p2p-call-dock-stats`
- Remaining `p2p-stats-*` occurrences are feature-level Stats panel selectors in `LobbyNetworkPanel` and its component tests, not top-level window IDs.

### Implementation Pass 25 - Completed 2026-07-17

Delivered:

- Tightened P2P Stats progressive disclosure after reviewing the diagnostics behavior against the section-first/mobile-first premise.
- Kept Connection open by default as the primary operational diagnostic.
- Collapsed Audio, Video, Games, and Files diagnostics by default so the Stats section opens as summary-first instead of raw-metrics-first.
- Added stable test IDs for P2P Stats tabs:
  - `p2p-stats-tab-network`
  - `p2p-stats-tab-audio`
  - `p2p-stats-tab-video`
  - `p2p-stats-tab-game`
  - `p2p-stats-tab-file`
- Updated the screen-share E2E to follow the real user path: open Stats, select Video, read the visible summary, then expand the diagnostics group before asserting raw `Source` rows.
- Cleaned remaining live help/comment residue that still taught the old P2P multi-window model:
  - command help now says `/p2p` opens the P2P Session Console;
  - P2P feature help now describes Call, Files, Games, and Stats as console sections;
  - test and internal comments no longer say status-bar actions focus "P2P windows" or "session windows".

Screenshots captured:

- `docs/plans/screenshots/media-session-visual-qa/p2p-desktop-stats-progressive-disclosure.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-stats-progressive-disclosure.png`

Visual findings:

- Desktop keeps the section-first console model: summary cards, tabs, topology, and one open Connection diagnostic fit without horizontal overflow.
- Mobile keeps the same hierarchy at phone width: session summary and tabs remain discoverable, advanced diagnostics are not a wall of raw rows on first view, and the section navigation cue remains visible.

Validation completed:

- P2P Stats component:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/lobby/lobby_network_panel_test.exs`
  - 1 test, 0 failures.
- Focused P2P screen-share E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts -g "screen share marks"`
  - 1 test, 0 failures.
- Focused P2P mini/stats E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts -g "mini mode, stats section"`
  - 1 test, 0 failures.
- Help/keyboard suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/help_live_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/help_system_feature_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/keyboard_shortcuts_test.exs`
  - 28 tests, 0 failures, 7 excluded.
- P2P LiveView flow suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs --include liveview_feature`
  - 25 tests, 0 failures.
- Hygiene:
  - `rtk git diff --check`
  - 0 whitespace errors.
- Full P2P + conference E2E after the cleanup:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 28 tests, 0 failures.
- Temporary visual QA:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/p2p-stats-progressive-disclosure-visual.tmp.spec.ts`
  - 1 test, 0 failures.
  - Spec removed after screenshots were captured.

Live-code residue search is now clean for:

- `session windows`
- `P2P windows`
- `P2P Statistics`
- `P2P Call Window`
- `Statistics window`
- `Dock statistics`
- `p2p-stats-window`, `p2p-games-window`, `p2p-files-window`
- `p2p_dock_stats`
- `p2p-call-dock-stats`
- `#p2p-stats`

Remaining `p2p-stats-*` occurrences are still deliberate feature-level Stats panel selectors, not top-level window artifacts.

Learnings:

- P2P tabs reduce scope, but they do not eliminate the need for progressive disclosure. Mobile still benefits from Connection first and raw media/channel rows on demand.
- E2E should assert the visible summary before expanding details. That keeps the test aligned with the product hierarchy instead of treating collapsed DOM content as the primary UX.
- Help catalogs are product surface too. Leaving old "session windows" copy in generated help would keep teaching the pre-console model even after code cleanup.

### Implementation Pass 26 - Completed 2026-07-17

Delivered:

- Refined P2P Setup and Conference Prejoin together as the same media-session entry pattern.
- Kept the primary path visible in both products:
  - preview;
  - peer/channel intent;
  - microphone/camera defaults;
  - device selectors.
- Moved secondary technical choices into compact advanced disclosures:
  - P2P: `Route and privacy`, with a visible `Direct preferred` / `Relay on` / `Relay unavailable` summary.
  - Conference: `Layout and route`, with a visible `Auto / Tile` style summary.
- Preserved all existing form inputs and lifecycle behavior:
  - P2P receive-only still uses the microphone/camera toggles;
  - P2P privacy relay remains submitted because the checkbox stays in the form;
  - Conference layout, self-view, and participant-sidebar defaults remain submitted because the selects/toggle stay in the form;
  - preview hooks, device enumeration, preferences, submit/cancel events, and test IDs remain intact.
- Reordered Conference Prejoin so devices are part of the primary entry flow before layout/route details, matching P2P Setup and reducing mobile scroll cost.

Screenshots captured:

- `docs/plans/screenshots/media-session-visual-qa/p2p-desktop-setup-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-setup-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-desktop-prejoin-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-mobile-prejoin-refined.png`

Visual findings:

- Desktop entry dialogs now feel like the same product family: preview on the left, operational choices on the right, and technical route/layout details as a lower-priority disclosure.
- Mobile no longer stacks route/topology/layout text above the submit area. Devices stay reachable in the first pass, while advanced choices remain discoverable through a compact row.
- The change improves desktop and mobile through one interface model, not by creating separate mobile-only variants.

Validation completed:

- Setup/prejoin component suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/p2p/setup_dialog_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/components/ui/group_call/pre_join_dialog_test.exs`
  - 5 tests, 0 failures.
- Temporary entry visual QA:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/media-session-entry-refinement-visual.tmp.spec.ts`
  - 2 tests, 0 failures.
  - Spec removed after screenshots were captured.
- Focused conference prejoin E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-group-call.spec.ts -g "pre-join dialog keeps"`
  - 1 test, 0 failures.
- Focused P2P setup/connect E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts -g "accepting the PM card"`
  - 1 test, 0 failures.
- Focused P2P + conference LiveView suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 59 tests, 0 failures.
- Full P2P + conference E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 28 tests, 0 failures.

Learnings:

- Setup/prejoin polish should not hide devices. The primary user question is still "what will happen when I join/send?", and device confidence belongs in that first pass.
- Route, privacy, layout, and room topology are important, but they are not equal-weight cards on mobile. A native disclosure keeps the capabilities available without making the dialog feel like a settings wall.
- Conference and P2P can share entry hierarchy while keeping domain differences: P2P exposes relay privacy; conference exposes layout/self-view.

### Implementation Readiness Checklist

Before coding starts, the plan is ready when these decisions are accepted:

- P2P default surface becomes one console, not four separate default windows.
- `p2p-call-window` is reused as the initial P2P console window for compatibility.
- `p2p-files`, `p2p-games`, and `p2p-stats` are not live compatibility surfaces; remove ghost lifecycle references before adding any future detach affordance.
- P2P mobile opens the console immediately after connect.
- Conference keeps `group-call-window` as its primary surface.
- Stats become summary-first inspectors, with old stats windows retained until the new inspector is stable.
- Shared visual primitives are presentational and do not own media/game/file lifecycle.

## Product Plan

### Phase 1: Product Architecture and Shared Primitives

1. Establish shared media-session primitives.
   - Compact icon scale.
   - Shared action button sizing.
   - Shared session header language.
   - Shared metric/status badges.
   - Shared inspector/tab pattern.
   - Status: first presentational primitives created in pass 4: `SectionNav` and `SummaryCard`.

2. Define the session shell.
   - One layout contract for mobile and desktop.
   - One navigation model for P2P and conference.
   - One inspector model for stats, participants, settings, files, and games.
   - Explicit empty/error/loading states.

3. Protect feature lifecycles.
   - Map WebRTC hooks, file transfer hooks, game surfaces, stats update paths, and existing test selectors.
   - Decide which DOM nodes must remain mounted even when their section is not visible.
   - Add tests around lifecycle assumptions before moving high-risk surfaces.

### Phase 2: P2P Console First

1. Fix P2P mobile reachability.
   - After accept/connect, open a real P2P session surface on mobile.
   - Do not rely on a tiny status strip or taskbar discovery.
   - Preserve existing media, file transfer, games, and stats behavior while changing how the user reaches them.

2. Refactor P2P into the console model.
   - Call as the primary tab.
   - Files, Games, and Stats as session sections.
   - Desktop can still expose taskbar/window affordances where useful, but the default path should be coherent.

3. Refine P2P setup.
   - First-pass hierarchy is implemented: preview and peer intent first, media choices and devices second, privacy relay and topology as supporting detail.
   - Remaining work is polish after shared primitives are extracted.

4. Validate P2P as a complete product.
   - Mobile setup, invite, connected console, call controls, files, games, stats, leave/end.
   - Desktop setup, invite, console, dock/inspector behavior, optional window compatibility if retained.

### Phase 3: Conference Console Alignment

1. Bring conference into the same visual system.
   - Reduce icon size and chrome weight.
   - Keep participant side panel on desktop.
   - Convert participants/stats/settings into mobile-friendly tabs or sheets.
   - Preserve the current WebRTC lifecycle and group call events.

2. Refine conference prejoin.
   - First-pass hierarchy is implemented: preview and primary action stay dominant, route/topology is compact, device selectors are consistent, and layout defaults are grouped.
   - Remaining work is polish after shared primitives are extracted.

3. Refine conference active call.
   - Mobile: prioritize stage, then controls, then people/stats/settings.
   - Desktop: keep stage plus people panel, with stats as an inspector.
   - Reduce repeated large icon usage throughout header, toolbar, participants, badges, reactions, and stats.

4. Validate conference as a complete product.
   - Mobile prejoin, active call, participant actions, stats, settings, leave/end.
   - Desktop prejoin, active call, participants, moderation, stats dock, layout changes.

### Phase 4: Unified Polish and Regression Pass

1. Validate with E2E and screenshots.
   - P2P desktop setup, invite, connected call, stats.
   - P2P mobile setup, invite, connected session, call controls, stats.
   - Conference desktop prejoin, active call, participants, stats.
   - Conference mobile prejoin, active call, participants, stats.

2. Add visual QA checkpoints.
   - 390px mobile, 768px tablet-ish, 1280px desktop.
   - Connected, waiting, degraded, reconnecting, failed, and ended states.
   - Long peer/channel names.
   - No camera, no microphone, receive-only, screen sharing, empty participants.

3. Finalize product coherence.
   - Same terms for Call, People/Participants, Stats, Settings, Files, Games.
   - Same button placement rules.
   - Same inspector/tab behavior.
   - Same stats summary language.
   - Same setup/prejoin hierarchy.

## Non-MVP Quality Bar

This effort is not done when the screens merely fit on mobile. It is done when:

- A new user can discover and operate the session without prior knowledge of the current window/taskbar model.
- A power user still has access to every existing feature.
- Mobile feels intentional and fast.
- Desktop feels composed and powerful.
- P2P and conference clearly belong to the same product family.
- The retro aesthetic feels premium, not accidental.
- The implementation has tests around the risky lifecycle paths.
- Fresh screenshots prove the experience across mobile and desktop.

## Complexity and Risks

This is medium-high complexity because the UI problem is connected to feature lifecycle.

Main risks:

- P2P media hooks may depend on current window mounting behavior.
- P2P files and games may depend on being present as separate windows.
- Mobile P2P currently avoids window burst intentionally, so replacing it needs a deliberate session surface, not just opening all desktop windows on a phone.
- Conference WebRTC and participant surfaces likely contain ignored/live hook areas that should not be moved casually.
- Existing E2E tests may depend on specific window IDs and test IDs.

The safest path is not to make tiny cosmetic edits first. Start with the hardest structural point: define the shared media-session model and make P2P mobile open a reachable session console. That will force the right abstractions for conference instead of creating two separate redesigns.

## Acceptance Criteria

P2P:

- On mobile, accepting or connecting a P2P session opens a usable session surface.
- The user can start/stop media, leave, and reach Files/Games/Stats without guessing.
- Desktop no longer feels like the default experience is a burst of unrelated windows.
- Setup is shorter and has clearer hierarchy on mobile and desktop.

Conference:

- Mobile call controls fit without overwhelming the media/participants area.
- Desktop keeps the strong single-surface model but with lighter chrome.
- Stats are readable as an inspector, not a dense raw metrics page by default.
- Prejoin uses the same setup language as P2P.

Shared:

- Icons are visually smaller while touch targets remain safe.
- Primary actions are obvious on mobile and desktop.
- The same interaction model works across viewport sizes.
- Screenshots show no horizontal overflow, clipped primary controls, or hidden core functionality.

## Implementation Pass 27: P2P Files and Games as Session Activities

Prompt:

- Re-evaluate whether Files and Games should remain two separate windows, capture screenshots, reflect on the best experience, and implement the refinement.

Baseline screenshots captured:

- `docs/plans/screenshots/media-session-visual-qa/p2p-desktop-files-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-files-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-desktop-games-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-games-baseline.png`

Baseline findings:

- The important feature is concurrency: call, file transfer, and game must continue to share the same P2P connection.
- The current Files surface technically supports that, but visually reads as an old standalone window: a narrow drop zone at the top followed by a large dead gray region.
- The current Games surface also supports the connection, but visually reads as a separate arcade catalog. Desktop is dense, while mobile becomes a two-column compressed grid with aggressive text truncation and oversized icons.
- Keeping Files and Games as literal default windows would make mobile worse and would preserve the old window/taskbar mental model. Keeping them as mounted session activities preserves the capability without creating two applications inside the same call.

Target experience:

- Files and Games remain independent feature modules, but the product surface presents them as activities inside one P2P session console.
- Files should be an always-available transfer activity: concise session header, peer-aware copy, clear drop/browse zone, and active transfer state in the same panel.
- Games should be an activity catalog that can be promoted to play state: concise header, readable game cards, smaller icons, one-column mobile catalog, multi-column desktop catalog, and a responsive canvas when playing.
- Hooks, ids, test ids, and event names stay stable: `lobby-file-transfer`, `FileTransferHook`, `lobby-file-input`, `lobby-file-panel`, `lobby-game-panel`, `lobby-game-consent`, `lobby-game-canvas`, `propose_game`, `respond_game`, `end_game`, and `dismiss_game_result`.

Implementation approach:

- Reuse media-session primitives where they fit, especially status/header and command/action button language.
- Keep the islands mounted by the P2P console; do not reintroduce separate default file/game windows as the primary experience.
- Refine both desktop and mobile through the same component markup and responsive constraints.
- Add focused component assertions for the new activity headers and keep the existing lifecycle assertions.
- Capture final screenshots for the same four states and compare them against baseline.

Implemented:

- `FilePanel` now reads as a P2P session activity instead of a small drop zone inside an old window.
  - Added a media-session status header with peer, max size, and ready/active/error state.
  - Expanded the drop/browse area to use the available desktop and mobile surface intentionally.
  - Preserved `lobby-file-transfer`, `FileTransferHook`, `lobby-file-input`, `lobby-file-panel`, validation error rendering, and file-transfer widget events.
- `GamePanel` now reads as a P2P session activity instead of a compressed arcade catalog.
  - Added a media-session status header with peer, catalog count, and ready/invite/waiting/playing state.
  - Changed the game catalog to one readable column on mobile, two columns on tablet-ish widths, and three columns on desktop.
  - Reduced game icon weight while preserving touch/click targets.
  - Made the playing canvas stage responsive while preserving `lobby-game-canvas` and `LobbyGameCanvasHook`.
- `P2PFileIsland` and `P2PGameIsland` documentation now describes the console-section model and keeps legacy window commands framed as compatibility behavior.
- E2E layout stability now checks Files/Games panel containers when those sections are active. The catalog itself is intentionally scrollable content, so it is not treated as a viewport-fitting container.

Final screenshots captured:

- `docs/plans/screenshots/media-session-visual-qa/p2p-desktop-files-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-files-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-desktop-games-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-games-refined.png`

Visual result:

- Files desktop no longer has a tiny white strip followed by unused gray space; the activity owns the surface and makes the drop/browse affordance central.
- Files mobile now has clear hierarchy: session header first, then a large touch-friendly file area.
- Games desktop keeps density but improves scanability with three comfortable columns and smaller icons.
- Games mobile no longer squeezes the catalog into two narrow columns; each game has a full-width row with readable title/tagline.

Validation completed:

- Component suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_file_island_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_game_island_test.exs`
  - 13 tests, 0 failures.
- Temporary visual QA:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/media-session-p2p-files-games-baseline.tmp.spec.ts`
  - 1 test, 0 failures.
  - Spec removed after screenshots were captured.
- Focused P2P file/game concurrency E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts -g "the auto-started call carries real video both ways; file and game share the connection"`
  - 1 test, 0 failures.
- Focused P2P LiveView suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs --include liveview_feature`
  - 25 tests, 0 failures.
- Full P2P + conference E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 28 tests, 0 failures.
- Diff hygiene:
  - `rtk git diff --check`
  - Clean.

Learning:

- The product requirement is simultaneous activity, not separate windows. Files and Games should remain independently stateful modules, but the user should experience them as activities inside one session workspace.
- A scrollable catalog is correct content behavior; layout tests should measure the section shell for overflow and let the catalog content scroll vertically.
- The same responsive structure improved both desktop and mobile: desktop gained better use of space, while mobile gained readability without a forked interface.

## Implementation Pass 28: P2P Files and Games Active States

Prompt:

- Attack the next step: refine real active states for Files and Games after the idle connected surfaces were improved.

Baseline screenshots captured:

- `docs/plans/screenshots/media-session-visual-qa/p2p-desktop-files-validation-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-files-validation-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-desktop-files-offer-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-files-offer-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-desktop-games-waiting-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-games-waiting-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-desktop-games-consent-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-games-consent-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-desktop-games-playing-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-games-playing-baseline.png`

Baseline findings:

- File validation was acceptable after Pass 27, but file offer/transfer still looked like a narrow technical widget instead of a session activity.
- Game invite and waiting states showed a disabled catalog behind the active decision, which made the user parse irrelevant controls.
- Game playing was functionally good, but the toolbar still needed clearer game context and the result card still followed the old compact widget pattern.
- The active states confirmed the same product rule: show the current user decision or activity as the main surface, and keep the call/game/file concurrency as supporting context.

Implemented:

- `FileTransfer` was redesigned as a media-session transfer card.
  - Larger file icon tile.
  - Clear state line: incoming offer, waiting for peer, transferring, failed, complete, etc.
  - Progress remains visible.
  - Accept/cancel actions are right-aligned.
  - Existing `file-transfer`, `file-transfer-accept`, and `file-transfer-cancel` test ids and events are preserved.
- `FilePanel` now centers active file transfer cards in the same large activity stage used by the dropzone.
  - Header state now distinguishes `Incoming`, `Offering`, `Active`, `Paused`, and `Check file`.
- `GamePanel` now treats pending proposals as focused states.
  - Incoming invite hides the disabled catalog and presents a decision card.
  - Outgoing waiting hides the disabled catalog and presents a waiting card with cancel.
  - Playing toolbar includes game context while preserving the canvas hook.
  - Final score uses a session-style result card with icon, outcome, score frame, and right-aligned return action.
- `p2p_session_events.ex` comment language now describes game close/cancel as a session action rather than a Games window action.

Final screenshots captured:

- `docs/plans/screenshots/media-session-visual-qa/p2p-desktop-files-validation-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-files-validation-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-desktop-files-offer-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-files-offer-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-desktop-games-waiting-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-games-waiting-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-desktop-games-consent-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-games-consent-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-desktop-games-playing-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/p2p-mobile-games-playing-refined.png`

Visual result:

- Files offer is now a focused transfer card inside a large stage, not a technical strip at the top of a gray window.
- Game consent is now a single decision card with no disabled catalog noise.
- Game waiting is now a centered pending state with an explicit cancel action.
- Game playing remains compact and usable on mobile while retaining a composed desktop stage.
- Game final result is covered by component/LiveView state and now follows the same card language as the active states.

Validation completed:

- Component suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_file_island_test.exs apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/components/p2p_game_island_test.exs`
  - 13 tests, 0 failures.
- Temporary active-state visual QA:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/media-session-p2p-active-states-baseline.tmp.spec.ts`
  - 2 tests, 0 failures.
  - Spec removed after screenshots were captured.
- Focused P2P file/game concurrency E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts -g "the auto-started call carries real video both ways; file and game share the connection"`
  - 1 test, 0 failures.
- Focused P2P LiveView suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/p2p_session_flow_test.exs --include liveview_feature`
  - 25 tests, 0 failures.
- Full P2P + conference E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - Final tree state run: 27 passed, 1 flaky.
  - The flaky case was the unrelated conference prejoin test waiting for `chat-input-send` to become enabled; it passed on retry.
- Isolated flaky confirmation:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-group-call.spec.ts -g "pre-join dialog keeps preview and controls inside the window"`
  - 1 test, 0 failures.
- Diff hygiene:
  - `rtk git diff --check`
  - Clean.

Learning:

- Active states need a stronger focus rule than idle states. When the user must decide, wait, or watch a transfer, the catalog/dropzone should get out of the way.
- The same responsive panel can serve desktop and mobile if the primary state is framed as a session activity and scrollable secondary content is not shown by default.
- The file/game activity model now feels consistent across idle, validation, invite, offer, waiting, playing, and result states without creating mobile-specific forks.

## Implementation Pass 29: Conference People Active States

Prompt:

- Continue the original media-session elevation plan by refining active conference People states for both desktop and mobile.
- Preserve the existing conference features while improving the UI/UX standard as one responsive experience, not separate mobile and desktop products.

Baseline screenshots captured:

- `docs/plans/screenshots/media-session-visual-qa/conference-desktop-people-active-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-mobile-people-active-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-desktop-people-request-to-speak-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-mobile-people-request-to-speak-baseline.png`

Baseline findings:

- The participant list was functional, but each row was icon-heavy and compressed.
- In the desktop right rail, media indicators and the action menu competed with the participant name.
- In mobile People mode, the list had more width but still used the old compact row language, so identity, state, and actions were not visually separated.
- The request-to-speak queue worked, but it looked like a technical strip competing with the participant rows instead of a moderation queue.
- After the first refinement, the taller cards exposed a layout issue: the mobile console grid constrained the People panel to a short row, leaving empty space below and clipping active rows. The real problem was not only row density; the mobile console panel needed to own the available height.

Implemented:

- `GroupCall.Panel` participant rows now use a clearer participant-card structure.
  - Top area: role tile, nickname, active-speaker/hand/reaction badges, and status.
  - Bottom area: media state indicators and participant action menu aligned to the right.
  - This keeps names readable in the narrow desktop rail while remaining touch-friendly on mobile.
- Media indicators were reduced from the older large visual weight while keeping their state semantics and data attributes.
- The raised-hand queue was promoted into a more legible moderation block.
  - More breathing room.
  - Numbered request rows.
  - Allow-speak action remains right-aligned.
- The mobile conference console grid now lets non-stats console panels use the main available row instead of a short bottom row.
  - This fixes People mobile clipping and removes the dead empty space under the panel.
  - Desktop remains a stage plus right inspector rail.
- Preserved existing event and test contracts:
  - `group-call-participant-*`
  - `group-call-participant-actions-*`
  - `group-call-participant-hand-*`
  - `group-call-raised-hand-queue`
  - `group-call-queue-allow-speak-*`
  - media state data attributes for audio, video, screen, moderation, and quality.

Final screenshots captured:

- `docs/plans/screenshots/media-session-visual-qa/conference-desktop-people-active-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-mobile-people-active-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-desktop-people-request-to-speak-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-mobile-people-request-to-speak-refined.png`

Visual result:

- Desktop People now reads as a usable moderation rail: participant name remains legible, controls are predictable, and request-to-speak is visually distinct.
- Mobile People now uses the full available height, so active moderation states no longer appear clipped above the bottom call controls.
- Participant cards share one responsive hierarchy across desktop and mobile instead of maintaining a separate mobile-only interpretation.
- The request-to-speak state is clearer: the queue explains the pending action, while the participant row still shows the hand badge and muted media state.

Validation completed:

- Temporary conference People visual QA:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/conference-people-active-baseline.tmp.spec.ts`
  - 1 test, 0 failures.
  - Spec removed after baseline/refined screenshots were captured.
- Focused conference LiveView suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 34 tests, 0 failures.
- Focused moderation E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-group-call.spec.ts -g "request to speak lets a muted participant ask and moderator allow audio|bulk moderation mutes and turns off cameras for lower-ranked participants"`
  - 2 tests, 0 failures.
- Full P2P + conference E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 28 tests, 0 failures.
- Diff and temp-spec hygiene:
  - `rtk git diff --check`
  - Clean.
  - `rtk rg "conference-people-active-baseline.tmp|\\.tmp\\.spec" e2e/tests -n`
  - No temporary specs remaining.

Learning:

- The narrow desktop rail is the hardest constraint for People. If the row works there, mobile can usually use the same hierarchy with more breathing room.
- Participant identity must not share the same horizontal line with every media/action control in a narrow inspector. A two-line card preserves both scanability and control access.
- Active moderation states need two layers: a queue for the moderator's next decision and a participant row for persistent participant state.
- Mobile-first does not mean shrinking rows until they fit. In this case, the right fix was to let the console panel fill the available mobile workspace.

## Implementation Pass 30: Conference Settings and Stats

Prompt:

- Continue the conference part of the media-session elevation plan by refining `Settings` and `Stats` for desktop and mobile.
- Keep the same responsive product experience while improving both mobile and desktop UI/UX.

Baseline screenshots captured:

- `docs/plans/screenshots/media-session-visual-qa/conference-desktop-settings-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-mobile-settings-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-desktop-stats-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-mobile-stats-baseline.png`

Baseline findings:

- `Settings` was functional but visually underdeveloped. It showed a row of layout buttons and a tiny summary block, leaving most of the panel as unused gray space.
- On mobile, `Settings` had enough room but still felt like a leftover utility strip rather than a real settings panel.
- `Stats` already had good information architecture, but the desktop stats rail forced the summary cards into four columns, causing aggressive truncation.
- `Stats` mobile was closer to the desired result because the same summary cards had enough width in a two-column layout.
- The important constraint was the desktop rail: viewport breakpoints can be misleading inside narrow inspectors, so the layout must respect rail width and scanability.

Implemented:

- `Settings` now has a stronger panel hierarchy.
  - Header meta shows the current layout mode instead of generic "View" copy.
  - Layout controls sit inside a bordered command block with the current layout value.
  - Current state is shown through stacked status cards: Layout, People, and Self view.
  - Existing `LayoutControls` events and test ids remain unchanged.
- `StatsPanel` now uses a smaller conference header icon to reduce crowding.
- `StatsPanel` summary cards now stay in a two-column grid instead of switching to four columns on desktop.
  - Desktop rail values such as health, latency, media, and room remain readable.
  - Mobile keeps the same two-column summary that was already working well.
- Preserved existing test and feature contracts:
  - `group-call-settings-panel`
  - `group-call-layout-controls`
  - `group-call-inline-stats`
  - `group-call-stats-panel`
  - all stats summary/detail test ids.

Final screenshots captured:

- `docs/plans/screenshots/media-session-visual-qa/conference-desktop-settings-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-mobile-settings-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-desktop-stats-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-mobile-stats-refined.png`

Visual result:

- Settings desktop now reads as a real settings rail with a command block and readable state cards.
- Settings mobile uses the same hierarchy and avoids the previous "tiny controls above empty space" feel.
- Stats desktop no longer crushes four summary cards into a narrow rail; the summary is now readable at a glance.
- Stats mobile keeps the useful two-column summary while preserving detailed diagnostics below.

Validation completed:

- Temporary conference Settings/Stats visual QA:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/conference-settings-stats-baseline.tmp.spec.ts`
  - 1 test, 0 failures.
  - Spec removed after baseline/refined screenshots were captured.
- Focused conference LiveView suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 34 tests, 0 failures.
- Focused E2E for visual polish and docked stats:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-group-call.spec.ts -g "conference visual polish renders SVG reactions and captures desktop/mobile windows|conference can dock statistics beside the call and maximize the call window"`
  - 2 tests, 0 failures.
- Full P2P + conference E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 28 tests, 0 failures.
- Diff and temp-spec hygiene:
  - `rtk git diff --check`
  - Clean.
  - `rtk rg "conference-settings-stats-baseline.tmp|\\.tmp\\.spec" e2e/tests -n`
  - No temporary specs remaining.

Learning:

- Stats panels need to be optimized for their real container, not only for viewport size. A desktop rail can be narrower than a mobile panel.
- Settings should expose current state with the same visual weight as commands; otherwise the user sees controls but not the current mode.
- Reusing the same section layout worked again: desktop and mobile improved together without adding separate feature flows.

## Implementation Pass 31: Conference Final Consistency Sweep

Prompt:

- Review the conference as a complete product surface after the Call, People, Stats, Settings, mini, and docked states had each been improved.
- Look for inconsistencies between desktop and mobile instead of only checking isolated panels.

Baseline screenshots captured:

- `docs/plans/screenshots/media-session-visual-qa/conference-final-desktop-call-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-final-desktop-people-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-final-desktop-stats-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-final-desktop-settings-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-final-mobile-call-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-final-mobile-people-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-final-mobile-stats-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-final-mobile-settings-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-final-desktop-mini-baseline.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-final-desktop-docked-baseline.png`

Baseline findings:

- Desktop Call, People, Stats, Settings, and docked stats were visually coherent after the previous passes.
- People, Stats, and Settings mobile were also coherent and used the console workspace correctly.
- Call mobile with two participants was still weak: `data-tile-count="2"` forced two narrow video columns, so the synthetic video content and nameplates were cramped.
- Mini mode exposed a layout bug when activated after Settings/Stats. The inspector grid column was still reserved even though mini mode hides the inspector, leaving a large gray column beside the video surface.
- The issue was not a separate mobile/desktop flow; it was a shared conference stage rule that needed better responsive constraints.

Implemented:

- The conference video surface now explicitly fills its container width and height.
- Mobile auto/grid layout now stacks exactly two video tiles into one column under `700px`.
  - This gives each participant tile enough width for readable video and nameplate content.
  - Higher-density states can still use denser layouts when tile density rules apply.
- Mini mode now forces the video surface to one real column even when `data-tile-count` is present.
- `main_grid_class/1` now gates inspector/stats grid columns behind `!mini_mode?`.
  - Mini mode no longer inherits a hidden Settings/Stats/People column from the previously selected console section.
  - Mini remains a single-column media surface regardless of which tab was active before toggling mini.
- Assets were rebuilt for visual validation so Playwright used the updated CSS bundle.

Final screenshots captured:

- `docs/plans/screenshots/media-session-visual-qa/conference-final-desktop-call-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-final-desktop-people-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-final-desktop-stats-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-final-desktop-settings-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-final-mobile-call-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-final-mobile-people-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-final-mobile-stats-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-final-mobile-settings-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-final-desktop-mini-refined.png`
- `docs/plans/screenshots/media-session-visual-qa/conference-final-desktop-docked-refined.png`

Visual result:

- Mobile Call now stacks two participants vertically, making the video tiles and nameplates readable.
- Mini mode no longer shows a phantom gray inspector column and uses the available width consistently.
- Desktop Call, People, Stats, Settings, and docked stats stayed stable after the stage fix.
- The conference now behaves more like one responsive workspace: sections change the content emphasis, while media controls and navigation remain consistent.

Validation completed:

- Temporary conference final consistency visual QA:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/conference-final-consistency-baseline.tmp.spec.ts`
  - 1 test, 0 failures.
  - Spec removed after baseline/refined screenshots were captured.
- Focused conference LiveView suite:
  - `rtk mix test apps/retro_hex_chat_web/test/retro_hex_chat_web/live/chat_live/group_call_flow_test.exs --include liveview_feature`
  - 34 tests, 0 failures.
- Focused E2E for visual polish, mini mode, and docked stats:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-group-call.spec.ts -g "conference visual polish renders SVG reactions and captures desktop/mobile windows|mini mode keeps the call alive and preserves the remote video element|conference can dock statistics beside the call and maximize the call window"`
  - 3 tests, 0 failures.
- Full P2P + conference E2E:
  - `cd e2e && rtk ./node_modules/.bin/playwright test --project=chromium --reporter=line tests/chat-p2p.spec.ts tests/chat-group-call.spec.ts`
  - 28 tests, 0 failures.
- Diff and temp-spec hygiene:
  - `rtk git diff --check`
  - Clean.
  - `rtk rg "conference-final-consistency-baseline.tmp|\\.tmp\\.spec" e2e/tests -n`
  - No temporary specs remaining.

Learning:

- The holistic pass caught problems that isolated panel work missed. The Call stage was the real weak point once People, Stats, and Settings were coherent.
- Mini mode must not inherit layout columns from hidden console sections. Hidden panels should not reserve grid space.
- Mobile-first here means preserving the same call model while choosing tile geometry that gives media enough width to remain readable.

## Audit Pass 32: Fine Review Of Remaining Work

Prompt:

- Review the original plan after the P2P and conference implementation passes.
- Separate historical/resolved backlog from real remaining work so future agents do not chase stale plan text.

What was audited:

- The original "Current State", "Implementation Sequence", "Product Plan", "Readiness Checklist", "Acceptance Criteria", and all "Remaining work" notes in this file.
- Existing shared media-session components under `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/ui/media_session/`.
- P2P console routing and section state in `p2p_session_events.ex`, `p2p_session_console.ex`, and related LiveView/E2E tests.
- Conference section routing and surfaces in `group_call_events.ex`, `GroupCall.Panel`, `StatsPanel`, and related LiveView/E2E tests.
- Residue searches for old top-level P2P window concepts, stale dock naming, temp specs, and compatibility language.

Evidence from code/tests:

- Shared primitives present:
  - `action_button.ex`
  - `command_bar.ex`
  - `diagnostics_group.ex`
  - `header.ex`
  - `icon_button.ex`
  - `inspector_panel.ex`
  - `section_nav.ex`
  - `status_header.ex`
  - `summary_card.ex`
- P2P console state and routing are live:
  - `p2p_console_select`
  - `p2p_open_stats`
  - `p2p_open_files`
  - `p2p_open_games`
  - `open_p2p_console/2`
  - `p2p-console-section-call/files/games/stats`
- P2P E2E covers:
  - console visibility and section nav on desktop/mobile
  - Files/Games reachability inside the session console
  - receive-only
  - audio-only
  - screen share stats
  - recovery
  - mini/stats/maximize
  - invite decline/cancel states
- Conference E2E/LiveView covers:
  - Call/People/Stats/Settings section selection
  - mobile section-nav cue
  - layout stability
  - People list/moderation/request-to-speak
  - inline Stats
  - docked Stats
  - mini mode
  - screen share/focus/layout flows

Resolved items from historical plan:

- P2P mobile reachability is resolved.
- P2P multi-window default is resolved.
- P2P Files/Games as session activities are resolved.
- P2P Files/Games active states are resolved.
- P2P receive-only/audio-only/recovery regressions are covered.
- P2P dead top-level Files/Games/Stats managed-window cleanup is resolved.
- Conference section model is resolved.
- Conference People active/moderation states are resolved.
- Conference Stats and Settings are resolved.
- Conference final consistency sweep is resolved.
- Summary-first stats for P2P and conference are resolved.
- Shared presentational component extraction is sufficient for the current product state.

Not real blockers:

- The missing originally proposed `MediaSession.Shell`, `MetricBadge`, or `SetupLayout` files are not blockers. The implemented primitive set already covers the repeated visual work without moving lifecycle ownership into shared components.
- Remaining `p2p-stats-*`, `p2p-files-*`, and `p2p-games-*` selectors are feature/section selectors, not evidence that old standalone product windows are still active.
- No separate `group-call-stats-window` product path remains.
- No P2P island owns a legacy window-command compatibility contract.

Real remaining work:

1. Decide whether visual QA becomes permanent.
   - Current coverage has layout assertions and screenshot-byte checks in the normal E2E suite, plus temporary audited screenshots.
   - A permanent golden screenshot workflow is still a product/engineering policy decision.

2. Clean up documentation lifecycle after acceptance.
   - This document now has a current source-of-truth section at the top, but it still contains historical stale sections by design.
   - Once the work is accepted, archive or replace this file with a short final handoff document.

3. Keep the one-surface contract intact.
   - Do not add detached windows for P2P Files/Games/Stats or conference Stats.
   - Feature sections may keep clear `*-stats-*`, `*-files-*`, and `*-games-*` selector namespaces, but lifecycle/window-manager IDs should remain single-surface.

Conclusion:

- No unresolved product blocker remains from the original mobile/desktop elevation plan for P2P and conference.
- The next actionable step is not more feature redesign; it is either permanent visual-regression policy, final documentation cleanup, or commit/push/deploy if the user wants to ship the current state.
