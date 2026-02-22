# Category O: Sounds & Notifications

**Priority**: Green (Low impact)
**Dependencies**: None for core; B for notify sounds
**Existing**: O1 basic event sounds already implemented (new message, PM, user joined — retro wavs)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| O1 | Basic event sounds | Existing | New message, PM, user joined sounds (retro wavs) |
| O2 | Configurable sounds per event | New | Choose which sound plays for each event type |
| O3 | Connect/disconnect sounds | New | Sound when connecting to or disconnecting from the server |
| O4 | Sound mute toggle | New | Global button to mute/unmute all sounds |
| O5 | Visual flash/blink | New | Flash on treebar + title bar for activity in non-active windows |
| O6 | Typing indicator | New | Indicator in PMs that the other user is typing (modern feature) |

## Dependencies Detail

- O1 (existing) provides sound playback infrastructure
- O2 integrates with B2 (notify sounds) for buddy events
- O5 relates to D4 (highlight flash)
- O6 is PM-only, a modern addition
- O settings integrate into V (Options Dialog)

## Technical Notes (IRC/mIRC Reference)

- mIRC: Tools > Options > Sounds allows configuring per-event sounds
- mIRC supports WAV files for all events, with a test play button
- Events in mIRC: message, query (PM), notice, highlight, join, part, quit, kick, ctcp, invite
- Visual flash in mIRC: title bar and taskbar button flash when inactive window has activity
- Typing indicator did not exist in classic mIRC — this is a modern addition inspired by Slack/Discord

---

## Spec Command

```
/speckit.specify "Sounds & Notifications for RetroHexChat.

PROBLEM: While basic event sounds exist, users cannot customize which sounds play for which events, cannot mute all sounds at once, and have no visual indicators for activity in background windows. Additionally, PM conversations lack the typing indicator that modern users expect. The notification experience is incomplete compared to both classic mIRC and modern chat applications.

EXISTING CONTEXT: Basic event sounds are already implemented — new message, PM received, and user joined events play retro WAV-style sounds.

USER JOURNEY: A user wants to customize their notification experience. They open the Sounds configuration dialog and see a list of all event types: message, PM, highlight, join, part, kick, connect, disconnect, buddy online, buddy offline. Each event has a dropdown to select from available sounds or 'None' to disable. They assign a subtle 'ding' to regular messages but a louder 'alert' sound to highlights and PMs.

During a meeting, the user clicks the mute button in the toolbar/status bar. All sounds are silenced globally. The mute icon updates to show the muted state. They can unmute anytime with one click.

When a message arrives in a channel the user is not currently viewing, the treebar entry for that channel flashes/pulses and the browser title bar alternates to indicate activity. The flashing stops when the user switches to that channel. This visual notification can be configured per event type.

In a PM conversation, when the other user starts typing, a subtle 'Alice is typing...' indicator appears below the message area. The indicator appears shortly after the other user begins typing and disappears after a few seconds of inactivity or when their message is sent.

ACTORS: Any connected user (guest or registered). All preferences are per-user and persist for registered users. The mute state persists across page reloads.

EDGE CASES: If the browser tab is not focused, visual flash should still work on the browser tab title. If the user switches channels before the flash animation completes, it should stop immediately. The typing indicator should not appear if the other user only typed and deleted text without sending. Muting sounds should not affect the typing indicator (which is visual only). If both users are typing simultaneously in a PM, both should see each other's typing indicators.

NEGATIVE REQUIREMENTS: Sounds must NOT play when the application is muted. The typing indicator must NOT reveal what the user is typing — only that they are typing. Typing indicators must NOT appear in channel conversations (PM only — channels would be too noisy).

SCOPE: In scope — per-event sound configuration, connect/disconnect sounds, global mute toggle, visual flash/blink for treebar and title bar, PM typing indicator, sounds configuration dialog. Out of scope — custom sound file uploads (users choose from provided sounds only), desktop/push notifications (browser API), sound for specific channels only."
```
