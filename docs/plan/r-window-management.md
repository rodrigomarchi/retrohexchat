# Category R: Window Management

**Priority**: Red/Green (Mixed — R7 is Red, others are Green)
**Dependencies**: None
**Existing**: R1 basic MDI layout already implemented (treebar, chat area, nicklist)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| R1 | Basic MDI | Existing | Layout with treebar, chat area, nicklist |
| R2 | Detach/float windows | New | Detach a channel/PM window as a separate browser popup |
| R3 | Tile/Cascade windows | New | Arrange open windows in tile (side-by-side) or cascade (overlapping) |
| R4 | Minimize to switchbar | New | Minimize individual windows while keeping them in the switchbar |
| R5 | Custom window layouts | New | Save and restore window arrangements |
| R6 | Compact mode (treebar only) | New | Compact mode with only treebar, no switchbar |
| R7 | Status Window | New | Dedicated window for server messages (MOTD, notices, pings) |

## Dependencies Detail

- R1 (existing) provides the MDI foundation
- R7 (Status Window) is a critical dependency for: U1 (MOTD), U3/U4 (broadcasts), L4 (notice routing)
- R3-R6 are UI-only features with no domain dependencies

## Technical Notes (IRC/mIRC Reference)

- mIRC MDI: each channel/PM is a child window within the main frame
- mIRC supports: tile horizontal, tile vertical, cascade, arrange icons
- mIRC switchbar: a row of buttons at the top showing all open windows
- mIRC Status Window: always present, shows server messages, MOTD, raw numerics, PING/PONG
- In mIRC, windows can be maximized (fill MDI area), minimized (icon at bottom), or floating
- Detached windows in web context = browser popup windows (used by TheLounge, Kiwi IRC)

---

## Spec Command

```
/speckit.specify "Window Management for RetroHexChat.

PROBLEM: The current MDI layout shows one channel/PM at a time with a treebar for navigation. Users cannot view multiple conversations side-by-side, cannot detach a conversation into its own window for multi-monitor setups, and have no Status Window to see server messages. Classic mIRC provides rich window management that lets power users customize their workspace.

EXISTING CONTEXT: Basic MDI layout is already implemented with treebar (channel/PM navigation on the left), chat area (center), and nicklist (right).

USER JOURNEY: A power user wants to monitor #elixir and #phoenix simultaneously. They select 'Window > Tile Horizontal' from the menu, and the chat area splits to show both channels side by side. Alternatively, 'Tile Vertical' stacks them top and bottom. 'Cascade' overlaps them with offset for easy switching.

A user with dual monitors right-clicks #project in the treebar and selects 'Detach'. The channel opens in a separate browser popup window that they can drag to their second monitor. The detached window has full chat functionality. A 'Reattach' option brings it back into the main MDI area.

A user minimizes a quiet channel — its chat area hides but a button remains in the switchbar. The switchbar button shows an unread message count badge. Clicking the button restores the channel.

For users who prefer a clean interface, a 'Compact mode' toggle hides the switchbar entirely, leaving only the treebar for navigation.

Users can save their current window arrangement (which channels are open, their positions and sizes, which are minimized) as a named layout. Up to 3 layouts can be saved and restored later via menu.

The Status Window is a special, non-closable window that is always the first entry in the treebar. It receives: server connection status messages, MOTD (message of the day), service responses, ping/pong timing, and any messages not directed at a specific channel or PM. It acts as the IRC session console.

ACTORS: Any connected user. Layout preferences persist for registered users.

EDGE CASES: Detaching a window when popup blockers are active should show a helpful message explaining how to allow popups. If a detached window's browser popup is closed, the channel should reattach to the main MDI automatically. Tiling with only one channel open should simply maximize it. Saving a layout with detached windows should note them as detached. The Status Window must survive all navigation — it cannot be closed, only minimized.

NEGATIVE REQUIREMENTS: The Status Window must NOT be closable — only minimizable. Detached windows must NOT lose messages while detached (they must stay in sync). Tiling must NOT affect the treebar or nicklist positioning — only the chat area is rearranged.

SCOPE: In scope — detach/float windows as browser popups, tile (horizontal/vertical) and cascade, minimize to switchbar with unread badge, compact mode (no switchbar), save/restore up to 3 layouts, Status Window. Out of scope — drag-and-drop window rearrangement, resizable window panes within the MDI, tabbed window groups."
```
