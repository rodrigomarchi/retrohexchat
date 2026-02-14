# LiveView Event Contracts: Interactive Chat Elements

**Feature**: 027-interactive-chat-elements
**Date**: 2026-02-14

## Client → Server Events

### `"channel_hover"`

Triggered when user hovers over a channel name in chat. Server responds with channel tooltip data.

**Payload**:
```
{
  "channel": string    // Channel name (e.g., "#dev")
}
```

**Response**: Server pushes `"channel_tooltip"` event (see below).

**Handler**: `HoverEvents.handle_event("channel_hover", params, socket)`

---

### `"nick_hover"`

Triggered when user hovers over a nick for 500ms (idle). Server responds with whois data for the hover card.

**Payload**:
```
{
  "nick": string,     // Nickname being hovered
  "x": integer,       // Mouse X coordinate (viewport)
  "y": integer         // Mouse Y coordinate (viewport)
}
```

**Response**: Server updates `hover_card` assign → component re-renders.

**Handler**: `HoverEvents.handle_event("nick_hover", params, socket)`

**Validation**:
- Ignores if `nick` equals `socket.assigns.session.nickname` (own nick suppression — FR-014)
- Ignores if nick is empty or nil

---

### `"nick_hover_dismiss"`

Triggered when mouse leaves the nick element or hover card. Server clears the hover card.

**Payload**: `{}` (empty)

**Response**: Server resets `hover_card` assign to default.

**Handler**: `HoverEvents.handle_event("nick_hover_dismiss", _params, socket)`

---

### `"nick_click"`

Triggered when user single-clicks a nick (without text selection). Server-side is not needed — handled entirely client-side by inserting text into input.

**Note**: This is a client-only action. No LiveView event pushed.

---

### `"nick_dblclick"`

Triggered when user double-clicks a nick. Opens a PM conversation.

**Payload**:
```
{
  "nick": string      // Nickname to PM
}
```

**Response**: Server opens PM conversation, resets chat stream.

**Handler**: `HoverEvents.handle_event("nick_dblclick", params, socket)`

---

### `"channel_click"`

Triggered when user clicks a channel name. Joins or switches to the channel.

**Payload**:
```
{
  "channel": string   // Channel name (e.g., "#dev")
}
```

**Response**: Server joins channel (if not joined) or switches to it (if already joined).

**Handler**: `HoverEvents.handle_event("channel_click", params, socket)`

**Note**: The existing `"channel_dblclick"` event in `scroll_hook.js` already handles double-click on channels. This replaces/supplements it with single-click behavior.

## Server → Client Push Events

### `"channel_tooltip"`

Pushed in response to `"channel_hover"`. Contains data for the channel tooltip.

**Payload**:
```
{
  "channel": string,      // Channel name
  "count": integer,       // Current member count
  "joined": boolean       // Whether the user is already in this channel
}
```

**Client action**: Render a positioned tooltip near the hovered channel element showing "#channel — N users — Click to join" (or "Click to switch" if already joined).

---

### `"dismiss_hover_card"`

Pushed when the server detects a condition requiring hover card dismissal (e.g., nick change).

**Payload**: `{}` (empty)

**Client action**: Hide the hover card immediately.

## Event Flow Diagrams

### URL Hover (Client-Only)
```
User hovers URL → CSS :hover styles apply (underline, pointer)
                → Native title attribute shows page title or full URL
                → No server round-trip
```

### Channel Hover
```
User hovers channel → JS pushEvent("channel_hover", {channel})
                    → Server: get_state(channel) → count members
                    → Server: push_event("channel_tooltip", {channel, count, joined})
                    → JS: render tooltip at mouse position
User leaves channel → JS: hide tooltip
```

### Nick Hover Card
```
User hovers nick → JS: start 500ms timer
                 → (mouse moves) → JS: reset timer
                 → (500ms idle) → JS: pushEvent("nick_hover", {nick, x, y})
                 → Server: gather_whois_data → update hover_card assign
                 → LiveView: render hover_card component
User leaves nick → JS: pushEvent("nick_hover_dismiss")
                 → Server: reset hover_card assign
                 → LiveView: hide hover_card component
```

### Channel Click
```
User clicks channel → JS: check no text selected, no context menu open
                    → JS: pushEvent("channel_click", {channel})
                    → Server: check if already joined
                    → Server: join_channel() or switch_channel()
```

### Nick Click (Insert)
```
User clicks nick → JS: check no text selected, no context menu open
                 → JS: find input element
                 → JS: insertAtCursor(input, "Nick: ")
                 → No server round-trip
```

### Nick Double-Click (PM)
```
User dblclicks nick → JS: check no context menu open
                    → JS: pushEvent("nick_dblclick", {nick})
                    → Server: PM.open_pm_conversation(socket, nick)
```
